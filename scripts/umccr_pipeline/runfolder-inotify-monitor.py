import os.path
import sys
import atexit
import boto3
import json
import time
from inotify_simple import INotify, flags

WATCH_FLAGS = flags.CREATE  # Only interested in creation events
SLACK_TOPIC = "UMCCR runfolder monitor"
FLAG_FILE_NAME = "SequenceComplete.txt"

lambda_client = boto3.client('lambda')
pipeline_client = client = boto3.client('stepfunctions')
inotify_service = INotify()


# shutdown hook
@atexit.register
def cleanup():
    print("Shutting down...")
    inotify_service.close()
    print("Shutdown complete.")


def notify_slack(topic, title, message, lambda_name):
    payload = {
        "topic": topic,
        "title": title,
        "message": message
    }

    response = lambda_client.invoke(
        FunctionName=lambda_name,
        InvocationType='RequestResponse',
        Payload=json.dumps(payload)
    )

    return response


def start_pipeline(state_machine_arn, runfolder):
    payload = {
        "runfolder": runfolder
    }

    # the name has to be unique for at least 90 days
    execution_name = f"{runfolder}_execution_{round(time.time())}"

    response = client.start_execution(
        stateMachineArn=state_machine_arn,
        name=execution_name,
        input=json.dumps(payload)
    )

    return response


def run_monitor(monitored_path, slack_lambda_name, state_machine_arn):
    wd_dir_map = {}

    root_wd = inotify_service.add_watch(monitored_path, WATCH_FLAGS)
    wd_dir_map[root_wd] = monitored_path

    while 1:
        for event in inotify_service.read(read_delay=500):
            reported_flags = flags.from_mask(event.mask)

            # we're only interested in creation events
            if flags.CREATE in reported_flags:
                parent_path = wd_dir_map[event.wd]  # map the current watch descriptor to the watched folder
                current_path = os.path.join(parent_path, event.name)  # the full path of the event
                # and only directory creations in the root folder (direct sub-directories)
                if flags.ISDIR in reported_flags and event.wd is root_wd:
                    print(f"New runfolder detected: {current_path}")
                    try:
                        # try add a watch for the newly created directory (runfolder)
                        # these watches are automatically removed when the directory is deleted
                        wd = inotify_service.add_watch(current_path, WATCH_FLAGS)
                        wd_dir_map[wd] = current_path
                    except OSError as err:
                        notify_slack(topic=SLACK_TOPIC,
                                     title=event.name,
                                     message="ERROR creating watch for new runfolder!",
                                     lambda_name=slack_lambda_name)
                    notify_slack(topic=SLACK_TOPIC,
                                 title=event.name,
                                 message="New runfolder detected.",
                                 lambda_name=slack_lambda_name)
                # or the creation of the ready flag file
                elif event.name == FLAG_FILE_NAME:
                    print(f"New flag file detected: {current_path}")
                    # found a flag file, so the directory linked to the watch descriptor is the runfolder
                    runfolder = os.path.basename(parent_path)
                    notify_slack(topic=SLACK_TOPIC,
                                 title=runfolder,
                                 message="Runfolder ready flag detected.",
                                 lambda_name=slack_lambda_name)
                    start_pipeline(state_machine_arn=state_machine_arn,
                                   runfolder=runfolder)
                    # Could remove watch for this run, instead of watching it until the directory is removed
                # else:  ## Ignore other events
                    # print("IGNORED create event")
            # else: # Ignore event types we haven't signed up for (e.g. DELETE_SELF)
            #     print("Ups! Event happened that we didn't want to monitor...")


if __name__ == "__main__":
    # TODO: validate input
    path_to_monitor = sys.argv[1]
    slack_lambda_name = sys.argv[2]
    state_machine_arn = sys.argv[3]

    run_monitor(monitored_path=path_to_monitor, 
                slack_lambda_name=slack_lambda_name, 
                state_machine_arn=state_machine_arn)

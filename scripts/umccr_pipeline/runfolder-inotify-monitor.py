import os.path
import sys
import atexit
import boto3
import json
import time
import logging
from logging.handlers import RotatingFileHandler
from inotify_simple import INotify, flags

DEPLOY_ENV = os.getenv('DEPLOY_ENV')
SCRIPT = os.path.basename(__file__)
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

if DEPLOY_ENV == 'prod':
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
else:
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".dev.log")


WATCH_FLAGS = flags.CREATE  # Only interested in creation events
SLACK_TOPIC = "UMCCR runfolder monitor"
FLAG_FILE_NAME = "SequenceComplete.txt"

lambda_client = boto3.client('lambda')
pipeline_client = client = boto3.client('stepfunctions')
inotify_service = INotify()


# shutdown hook
@atexit.register
def cleanup():
    logger.warn("Shutting down...")
    inotify_service.close()
    logger.warn("Shutdown complete.")


def getLogger():
    new_logger = logging.getLogger(__name__)
    new_logger.setLevel(logging.DEBUG)

    # create a file handler
    handler = RotatingFileHandler(filename=LOG_FILE_NAME, maxBytes=100000000, backupCount=5)
    handler.setLevel(logging.DEBUG)

    # create a logging format
    formatter = logging.Formatter('%(asctime)s - %(module)s - %(name)s - %(levelname)s : %(lineno)d - %(message)s')
    handler.setFormatter(formatter)

    # add the handlers to the logger
    new_logger.addHandler(handler)

    return new_logger


def notify_slack(topic, title, message, lambda_name):
    logger.debug(f"Sending slack message: {message} with title: {title}")
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
    logger.info(f"Starting pipeline for {runfolder}")
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
                    logger.info(f"New runfolder detected: {current_path}")
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
                    logger.info(f"New flag file detected: {current_path}")
                    # found a flag file, so the directory linked to the watch descriptor is the runfolder
                    runfolder = os.path.basename(parent_path)
                    notify_slack(topic=SLACK_TOPIC,
                                 title=runfolder,
                                 message="Runfolder ready flag detected.",
                                 lambda_name=slack_lambda_name)
                    start_pipeline(state_machine_arn=state_machine_arn,
                                   runfolder=runfolder)
                    # Could remove watch for this run, instead of watching it until the directory is removed
                else:  # Ignore other events
                    logger.debug(f"Ignored CREATE event for {event.name}")
            else:  # Ignore event types we haven't signed up for (e.g. DELETE_SELF)
                logger.debug(f"Ignored event with flags {reported_flags} for {event.name}")


if __name__ == "__main__":
    logger = getLogger()

    # TODO: validate input
    path_to_monitor = sys.argv[1]
    slack_lambda_name = sys.argv[2]
    state_machine_arn = sys.argv[3]

    logger.warn(f"Starting runfolder monitor on path: {path_to_monitor}")

    run_monitor(monitored_path=path_to_monitor, 
                slack_lambda_name=slack_lambda_name, 
                state_machine_arn=state_machine_arn)

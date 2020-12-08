import json
import boto3

SUCCESS = 'success'
FAILURE = 'failure'

sfn_client = boto3.client('stepfunctions')


def get_callback_token(sns_record):
    sns_msg = json.loads(sns_record.get('Message'))
    task_id = sns_msg['id']
    print(f"Processing task {task_id}")
    task_name = sns_msg['name']
    task_desc = sns_msg['description']
    if "SHOWCASE" in task_name:
        # extract callback token
        token = task_desc
    else:
        # ignore
        token = None
        print(f"Not a showcase task: {task_name}")
    print(f"Extracted callback token {token}")

    return token


def extract_token_status(event):
    token = None
    records = event.get('Records')
    if len(records) == 1:
        record = records[0]
        if record.get('EventSource') == 'aws:sns' and record.get('Sns'):
            sns_record = record.get('Sns')

            if sns_record.get('MessageAttributes'):
                sns_msg_atts = sns_record.get('MessageAttributes')
                event_type = sns_msg_atts['type']['Value']
                action_type = sns_msg_atts['action']['Value']
                if event_type == 'tes.runs':
                    if action_type.lower() == 'updated':
                        sns_msg = json.loads(sns_record.get('Message'))
                        task_status = sns_msg['status'].lower()
                        if task_status == 'completed':
                            status = SUCCESS
                        elif task_status == 'aborted' or task_status == 'failed' or task_status == 'timedout':
                            status = FAILURE
                        else:
                            # Ignore others like 'Pending' or 'Running'
                            print(f"Ignoring: {task_status}")

                        token = get_callback_token(sns_record)
                    else:
                        # Ignore others like 'Created'
                        print(f"Ignoring action: {action_type}")
                else:
                    # Ignore others like 'gds.*'
                    print(f"Ignoring event type {event_type}")
            else:
                raise ValueError("Unexpected Message Format! No 'MessageAttributes'")
        else:
            raise ValueError("Unexpected Message Format! Not an SNS record.")
    else:
        raise ValueError("Unexpected Message Format! Expected exactly one record.")

    return token, status


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    callback_token, status = extract_token_status(event)

    if status == SUCCESS:
        sfn_client.send_task_success(
            taskToken=callback_token,
            output='"success"'
        )
    elif status == FAILURE:
        sfn_client.send_task_failure(
            taskToken=callback_token,
            output='"failure"'
        )
    else:
        # do nothing
        print(f"Ignoring status {status}.")

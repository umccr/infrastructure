import json
import boto3

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


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    records = event.get('Records')
    if len(records) == 1:
        record = records[0]
        if record.get('EventSource') == 'aws:sns' and record.get('Sns'):
            sns_record = record.get('Sns')

            if sns_record.get('MessageAttributes'):
                if sns_record['MessageAttributes']['type']['Value'] == 'tes.runs':
                    callback_token = get_callback_token(sns_record)
                else:
                    # ignore
                    print("XXX")

        else:
            raise ValueError("Unexpected Message Format!")
    else:
        raise ValueError("Unexpected Message Format!")

    if callback_token:
        sfn_client.send_task_success(
            taskToken=callback_token,
            output='{"status": "success"}'
        )

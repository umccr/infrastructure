import os
import json
import boto3
import http.client
from dateutil.parser import parse

slack_host = os.environ.get("SLACK_HOST")
slack_channel = os.environ.get("SLACK_CHANNEL")
GREEN = 'good'
RED = 'danger'
BLUE = '#439FE0'
GRAY = '#dddddd'
BLACK = '#000000'

ssm_client = boto3.client('ssm')

headers = {
    'Content-Type': 'application/json',
}


def getSSMParam(name):
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    return ssm_client.get_parameter(
                Name=name,
                WithDecryption=True
           )['Parameter']['Value']


def call_slack_webhook(sender, topic, attachments):
    slack_webhook_endpoint = '/services/' + getSSMParam("/slack/webhook/id")

    connection = http.client.HTTPSConnection(slack_host)

    post_data = {
        "channel": slack_channel,
        "username": sender,
        "text": "*" + topic + "*",
        "icon_emoji": ":aws_logo:",
        "attachments": attachments
    }

    connection.request("POST", slack_webhook_endpoint, json.dumps(post_data), headers)
    response = connection.getresponse()
    connection.close()

    return response.status


def lambda_handler(event, context):
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")
    print("Invocation context:")
    print(f"LogGroup: {context.log_group_name}")
    print(f"LogStream: {context.log_stream_name}")
    print(f"RequestId: {context.aws_request_id}")
    print(f"FunctionName: {context.function_name}")

    # we expect events of a defined format
    records = event.get('Records')
    if len(records) == 1:
        record = records[0]
        if record.get('EventSource') == 'aws:sns' and record.get('Sns'):
            sns_record = record.get('Sns')
            sns_record_date = parse(sns_record.get('Timestamp'))

            sns_msg = json.loads(sns_record.get('Message'))
            task_id = sns_msg['id']
            task_name = sns_msg['name']
            task_status = sns_msg['status']
            task_description = sns_msg['description']
            task_crated_time = sns_msg['timeCreated']
            task_created_by = sns_msg['createdBy']

            sns_msg_atts = sns_record.get('MessageAttributes')
            stratus_action = sns_msg_atts['action']['Value']
            stratus_action_date = sns_msg_atts['actiondate']['Value']
            stratus_action_type = sns_msg_atts['type']['Value']
            stratus_produced_by = sns_msg_atts['producedby']['Value']

            action = stratus_action.lower()
            status = task_status.lower()
            if action == "created":
                slack_color = BLUE
            elif action == 'updated' and (status == 'pending' or status == 'running'):
                slack_color = GRAY
            elif action == 'updated' and status == 'completed':
                slack_color = GREEN
            elif action == 'updated' and (status == 'aborted' or status == 'failed'):
                slack_color = RED
            else:
                slack_color = BLACK

            slack_sender = "Illumina Application Platform"
            slack_topic = f"Notification from {stratus_action_type}"
            slack_attachment = [
                {
                    "fallback": f"Task {task_name} update: {task_status}",
                    "color": slack_color,
                    "pretext": task_name,
                    "title": f"Task ID: {task_id}",
                    "text": task_description,
                    "fields": [
                        {
                            "title": "Action",
                            "value": stratus_action,
                            "short": True
                        },
                        {
                            "title": "Action Type",
                            "value": stratus_action_type,
                            "short": True
                        },
                        {
                            "title": "Action Date",
                            "value": stratus_action_date,
                            "short": True
                        },
                        {
                            "title": "Produced By",
                            "value": stratus_produced_by,
                            "short": True
                        },
                        {
                            "title": "Task Created At",
                            "value": task_crated_time,
                            "short": True
                        },
                        {
                            "title": "Task Created By",
                            "value": task_created_by,
                            "short": True
                        }
                    ],
                    "footer": "IAP TES Task",
                    "ts": int(sns_record_date.timestamp())
                }
            ]

        else:
            raise ValueError("Unexpected Message Format!")
    else:
        raise ValueError("Unexpected Message Format!")

    # Forward the data to Slack
    try:
        print(f"Slack message: sender: ({slack_sender}), topic: ({slack_topic}) and attachments: {json.dumps(slack_attachment)}")
        response = call_slack_webhook(slack_sender, slack_topic, slack_attachment)
        print(f"Response status: {response}")
        return event

    except Exception as e:
        print(e)

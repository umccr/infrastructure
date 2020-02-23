import os
import json
import boto3
import http.client
from dateutil.parser import parse

slack_host = os.environ.get("SLACK_HOST")
slack_channel = os.environ.get("SLACK_CHANNEL")
# Colours
GREEN = '#36a64f'
RED = '#ff0000'
BLUE = '#439FE0'
GRAY = '#dddddd'
BLACK = '#000000'

ssm_client = boto3.client('ssm')

headers = {
    'Content-Type': 'application/json',
}


def getAwsAccountName(id):
    if id == '472057503814':
        return 'prod'
    elif id == '843407916570':
        return 'dev (new)'
    elif id == '620123204273':
        return 'dev (old)'
    elif id == '602836945884':
        return 'agha'
    else:
        return id


def getCreatorFromId(id):
    if id == 'c9688651-7872-3753-8146-ffa41c177aa1':
        return f"{id} (Vlad Saveliev)"
    elif id == '567d89e4-de8b-3688-a733-d2a979eb510e':
        return f"{id} (Peter Diakumis)"
    elif id == '1678890e-b107-3974-a47d-0bb532a64ad6':
        return f"{id} (Roman Valls - unimelb)"
    elif id == '9c925fa3-9b93-3f14-92a3-d35488ab1cc4':
        return f"{id} (Roman Valls)"
    elif id == '8abf754b-e94f-3841-b44b-75d10d33588b':
        return f"{id} (Sehrish unimelb)"
    elif id == 'd24913a8-676f-39f3-9250-7cf22fbc48c8':
        return f"{id} (Sehrish Kanwal)"
    elif id == '7eec7332-f780-3edc-bb70-c4f711398f1c':
        return f"{id} (Florian - unimelb)"
    elif id == '6039c53c-d362-3dd6-9294-46f08d8994ff':
        return f"{id} (Florian Reisinger)"
    elif id == '57a99faa-ae79-33f8-9736-454a36b06a43':
        return f"{id} (Service User)"
    elif id == 'ef928f99-662d-3e9f-8476-303131e9a58a':
        return f"{id} (Karey Cheong)"
    elif id == 'a46c2704-4568-3a39-b934-45bc9b352ac8':
        return f"{id} (Voula Dimitriadis)"
    elif id == '6696900a-96ea-372a-bc00-ca6bbe19bf7b':
        return f"{id} (Kym Pham)"
    elif id == '3ed6bc8a-ba5a-3ec3-9e25-361703c7ba20':
        return f"{id} (Egan Lohman)"
    elif id == 'b2f0ff65-c77b-37bc-af87-68a89c2f8d27':
        return f"{id} (Alexis Lucattini)"
    elif id == '46258763-7c48-3a1c-8c5f-04003bf74e5a':
        return f"{id} (Alexis - unimelb)"
    else:
        return f"{id} (unknown)"


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
    print(f"Slack POST data: {json.dumps(post_data)}")

    connection.request("POST", slack_webhook_endpoint, json.dumps(post_data), headers)
    response = connection.getresponse()
    print(f"Slack webhook response: {response}")
    connection.close()

    return response.status


def slack_message_not_supported(sns_record):
    aws_account = sns_record.get('TopicArn').split(':')[4]
    sns_record_date = parse(sns_record.get('Timestamp'))

    sns_msg_atts = sns_record.get('MessageAttributes')
    stratus_action = sns_msg_atts['action']['Value']
    stratus_action_date = sns_msg_atts['actiondate']['Value']
    stratus_action_type = sns_msg_atts['type']['Value']
    stratus_produced_by = sns_msg_atts['producedby']['Value']

    sns_msg = json.loads(sns_record.get('Message'))
    iap_id = sns_msg['id']
    iap_crated_time = sns_msg['timeCreated']
    iap_created_by = sns_msg['createdBy']

    slack_color = GRAY

    slack_sender = "Illumina Application Platform"
    slack_topic = f"Notification from {stratus_action_type}"
    slack_attachment = [
        {
            "fallback": f"Unsupported notification",
            "color": slack_color,
            "title": f"IAP ID: {iap_id}",
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
                    "value": iap_crated_time,
                    "short": True
                },
                {
                    "title": "Task Created By",
                    "value": getCreatorFromId(iap_created_by),
                    "short": True
                },
                {
                    "title": "AWS Account",
                    "value": getAwsAccountName(aws_account),
                    "short": True
                }
            ],
            "footer": "IAP Notification",
            "ts": int(sns_record_date.timestamp())
        }
    ]
    return slack_sender, slack_topic, slack_attachment


def slack_message_from_tes_runs(sns_record):
    # NOTE: IAP NES TES status:  "Pending", "Running", "Completed", "Failed", "TimedOut", "Aborted"

    aws_account = sns_record.get('TopicArn').split(':')[4]
    sns_record_date = parse(sns_record.get('Timestamp'))

    sns_msg_atts = sns_record.get('MessageAttributes')
    stratus_action = sns_msg_atts['action']['Value']
    stratus_action_date = sns_msg_atts['actiondate']['Value']
    stratus_action_type = sns_msg_atts['type']['Value']
    stratus_produced_by = sns_msg_atts['producedby']['Value']

    sns_msg = json.loads(sns_record.get('Message'))
    task_id = sns_msg['id']
    task_name = sns_msg['name']
    task_status = sns_msg['status']
    task_description = sns_msg['description']
    if 'SHOWCASE' in task_name:
        task_description = 'SFN task callback token'
    task_crated_time = sns_msg['timeCreated']
    task_created_by = sns_msg['createdBy']

    action = stratus_action.lower()
    status = task_status.lower()
    if action == 'created':
        slack_color = BLUE
    elif action == 'updated' and (status == 'pending' or status == 'running'):
        slack_color = GRAY
    elif action == 'updated' and status == 'completed':
        slack_color = GREEN
    elif action == 'updated' and (status == 'aborted' or status == 'failed' or status == 'timedout'):
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
                    "title": "Action Status",
                    "value": status.upper(),
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
                    "value": getCreatorFromId(task_created_by),
                    "short": True
                },
                {
                    "title": "AWS Account",
                    "value": getAwsAccountName(aws_account),
                    "short": True
                }
            ],
            "footer": "IAP TES Task",
            "ts": int(sns_record_date.timestamp())
        }
    ]
    return slack_sender, slack_topic, slack_attachment


def slack_message_from_gds_uploaded(sns_record):
    # TODO: extend to other gds actions, items
    aws_account = sns_record.get('TopicArn').split(':')[4]
    sns_record_date = parse(sns_record.get('Timestamp'))

    sns_msg_atts = sns_record.get('MessageAttributes')
    stratus_action = sns_msg_atts['action']['Value']
    stratus_action_date = sns_msg_atts['actiondate']['Value']
    stratus_action_type = sns_msg_atts['type']['Value']
    stratus_produced_by = sns_msg_atts['producedby']['Value']

    sns_msg = json.loads(sns_record.get('Message'))
    file_id = sns_msg['id']
    file_name = sns_msg['name']
    file_path = sns_msg['path']
    volumn_name = sns_msg['volumeName']
    file_crated_time = sns_msg['timeCreated']
    file_created_by = sns_msg['createdBy']

    slack_color = GREEN

    slack_sender = "Illumina Application Platform"
    slack_topic = f"Notification from {stratus_action_type}"
    slack_attachment = [
        {
            "fallback": f"File {file_name} {stratus_action}",
            "color": slack_color,
            "pretext": file_name,
            "title": f"File ID: {file_id}",
            "text": file_path,
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
                    "title": "Volumn name",
                    "value": volumn_name,
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
                    "title": "File Created At",
                    "value": file_crated_time,
                    "short": True
                },
                {
                    "title": "File Created By",
                    "value": getCreatorFromId(file_created_by),
                    "short": True
                },
                {
                    "title": "AWS Account",
                    "value": getAwsAccountName(aws_account),
                    "short": True
                }
            ],
            "footer": "IAP GDS Event",
            "ts": int(sns_record_date.timestamp())
        }
    ]
    return slack_sender, slack_topic, slack_attachment


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

            if sns_record.get('MessageAttributes'):
                if sns_record['MessageAttributes']['type']['Value'] == 'gds.files':
                    slack_sender, slack_topic, slack_attachment = slack_message_from_gds_uploaded(sns_record)
                elif sns_record['MessageAttributes']['type']['Value'] == 'tes.runs':
                    slack_sender, slack_topic, slack_attachment = slack_message_from_tes_runs(sns_record)
                else:
                    slack_sender, slack_topic, slack_attachment = slack_message_not_supported(sns_record)

        else:
            raise ValueError("Unexpected Message Format!")
    else:
        raise ValueError("Unexpected Message Format!")

    # Forward the data to Slack
    try:
        print(f"Slack sender: ({slack_sender}), topic: ({slack_topic}) and attachments: {json.dumps(slack_attachment)}")
        response = call_slack_webhook(slack_sender, slack_topic, slack_attachment)
        print(f"Response status: {response}")
        return event

    except Exception as e:
        print(e)

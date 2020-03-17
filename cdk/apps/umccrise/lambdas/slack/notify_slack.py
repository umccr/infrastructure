import os
import json
import boto3
import http.client
from dateutil.parser import parse

slack_host = os.environ.get('SLACK_HOST')
slack_channel = os.environ.get('SLACK_CHANNEL')
ecr_name = os.environ.get('ECR_NAME')
aws_account = os.environ.get('AWS_ACCOUNT')
# Colours
GREEN = '#36a64f'
RED = '#ff0000'
BLUE = '#439FE0'
GRAY = '#dddddd'
BLACK = '#000000'

ssm_client = boto3.client('ssm')
ecr_client = boto3.client('ecr')

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
    connection.close()

    return response.status


def get_image_tag(commit_id):
    short_commit_id = commit_id[:10]

    # TODO: paging?
    image_list = ecr_client.list_images(
        registryId=aws_account,
        repositoryName=ecr_name
    )
    print(f"Image list: {image_list}")

    for image in image_list['imageIds']:
        if short_commit_id in image['imageTag']:
            print(f"Found image tag: {image['imageTag']}")
            return image['imageTag']


def slack_message_from_codebuild(message):
    # TODO: how to get the docker image version? (i.e. GH tag and commit ID)

    message_source = message.get('source')
    message_account = message.get('account')
    message_time = parse(message.get('time'))
    message_detail = message.get('detail')

    build_status = message_detail.get('build-status')
    build_project = message_detail.get('project-name')
    build_log_group = f"/aws/codebuild/{build_project}"
    build_id = message_detail.get('build-id')
    build_info = message_detail.get('additional-information')

    commit_id = build_info.get('source-version')
    build_log_stream = str(build_id).rpartition(':')[2]
    build_initiator = build_info.get('initiator')
    build_start_time = build_info.get('build-start-time')
    build_link = build_info.get('logs').get('deep-link')
    if 'group=null' in build_link or 'stream=null' in build_link:
        build_link = "https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-2#logEvent:" \
            f"group={build_log_group};stream={build_log_stream}"

    image_tag = 'N/A'  # We can only have an image if the build succeeded
    if build_status == 'IN_PROGRESS':
        slack_color = BLUE
    elif build_status == 'SUCCEEDED':
        slack_color = GREEN
        image_tag = get_image_tag(commit_id)
    elif build_status == 'FAILED':
        slack_color = RED
    else:
        slack_color = GRAY

    slack_sender = "AWS CodeBuild state change"
    slack_topic = f"Build project: {build_project}"
    slack_attachment = [
        {
            "fallback": f"CodeBuild {build_project} update: {build_status}",
            "color": slack_color,
            "title": f"Build ID: {build_id}",
            "fields": [
                {
                    "title": "Build Status",
                    "value": build_status,
                    "short": True
                },
                {
                    "title": "Image tag",
                    "value": image_tag,
                    "short": True
                },
                {
                    "title": "Source",
                    "value": message_source,
                    "short": True
                },
                {
                    "title": "Initiator",
                    "value": build_initiator,
                    "short": True
                },
                {
                    "title": "Build Start Time",
                    "value": build_start_time,
                    "short": True
                },
                {
                    "title": "AWS Account",
                    "value": getAwsAccountName(message_account),
                    "short": True
                }
            ],
            "footer": "IAP TES Task",
            "ts": int(message_time.timestamp())
        }
    ]
    if build_link:
        print(f"Adding CW link {build_link}")
        slack_attachment[0]["title_link"] = build_link
    else:
        print("Not adding CW link")

    return slack_sender, slack_topic, slack_attachment


def lambda_handler(event, context):
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")
    # print(f"Invocation context: {json.dumps(context)}")

    # we expect events of a defined format (an SNS event with a CodeBuild message body)
    records = event.get('Records')
    if len(records) == 1:
        record = records[0]
        if record.get('EventSource') == 'aws:sns' and record.get('Sns'):
            sns_record = record.get('Sns')
            codebuild_message = json.loads(sns_record.get('Message'))
            print(f"Extracted Build message: {json.dumps(codebuild_message)}")

            # TODO: get container image version/tag (possibly via separate API call)
            slack_sender, slack_topic, slack_attachment = slack_message_from_codebuild(codebuild_message)

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

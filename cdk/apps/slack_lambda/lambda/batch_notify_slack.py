import os
import json
import boto3
import http.client

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


def lambda_handler(event, context):
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")
    # print(f"Invocation context: {json.dumps(context)}")

    # we expect events of a defined format
    if event.get('source') == 'aws.batch' and event.get('detail-type') == 'Batch Job State Change':
        print("Processing Batch event...")
        event_detail = event.get('detail')
        aws_account = event.get('account')
        event_region = event.get('region')

        batch_job_name = event_detail.get('jobName')
        batch_job_id = event_detail.get('jobId')
        batch_job_status = event_detail.get('status').lower()
        if batch_job_status == 'succeeded':
            slack_color = GREEN
        elif batch_job_status == 'failed':
            slack_color = RED
        elif batch_job_status == 'runnable':
            slack_color = BLUE
        else:
            slack_color = GRAY
        batch_job_ts = int(event_detail.get('createdAt') / 1000)
        batch_job_definition = event_detail.get('jobDefinition')
        batch_job_definition_short = batch_job_definition.split('/')[1]

        batch_container = event_detail.get('container')
        container_image = batch_container.get('image')
        container_vcpu = batch_container.get('vcpus')
        container_mem = batch_container.get('memory')
        log_stream_name = batch_container.get('logStreamName')
        print(f"Log stream name: {log_stream_name}")

        slack_sender = "AWS Batch job status change"
        slack_topic = f"Job Name: {batch_job_name}"
        slack_attachment = [
            {
                "mrkdwn_in": ["pretext"],
                "fallback": f"Job {batch_job_name} {batch_job_status}",
                "color": slack_color,
                "pretext": f"Status: *{batch_job_status.upper()}*",
                "title": f"JobID: {batch_job_id}",
                "text": "Batch Job Attributes:",
                "fields": [
                    {
                        "title": "Job Definition",
                        "value": batch_job_definition_short,
                        "short": True
                    },
                    {
                        "title": "Container Image",
                        "value": container_image,
                        "short": True
                    },
                    {
                        "title": "Job VCPUs",
                        "value": container_vcpu,
                        "short": True
                    },
                    {
                        "title": "Job Memory",
                        "value": container_mem,
                        "short": True
                    },
                    {
                        "title": "AWS Account",
                        "value": getAwsAccountName(aws_account),
                        "short": True
                    }
                ],
                "footer": "AWS Batch Job",
                "ts": batch_job_ts
            }
        ]
        if log_stream_name:
            print("Adding CW link")
            slack_attachment[0]["title_link"] = f"https://{event_region}.console.aws.amazon.com/cloudwatch/home?region={event_region}#logEventViewer:group=/aws/batch/job;stream={log_stream_name}"
        else:
            print("Not adding CW link")

    else:
        raise ValueError("Unexpected event format!")

    # Forward the data to Slack
    try:
        print(f"Sender: ({slack_sender}), topic: ({slack_topic}) and attachments: {json.dumps(slack_attachment)}")
        response = call_slack_webhook(slack_sender, slack_topic, slack_attachment)
        print(f"Response status: {response}")
        return event

    except Exception as e:
        print(e)

import os
import json
import boto3
import http.client

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
    print("Slack POST data:")
    print(post_data)

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
        batch_job_ts = event_detail.get('createdAt')
        batch_job_definition = event_detail.get('jobDefinition')
        batch_job_definition_short = batch_job_definition.split('/')[1]
        batch_job_definition_short_name = batch_job_definition_short.split(':')[0]

        batch_container = event_detail.get('container')
        container_image = batch_container.get('image')
        container_vcpu = batch_container.get('vcpus')
        container_mem = batch_container.get('memory')

        slack_sender = "AWS Batch job status change"
        slack_topic = f"Job Name: {batch_job_name}"
        slack_attachment = [
            {
                "fallback": f"Job {batch_job_name} {batch_job_status}",
                "color": slack_color,
                "pretext": f"{batch_job_name}: {batch_job_status}",
                "title": f"JobID: {batch_job_id}",
                "title_link": f"https://{event_region}.console.aws.amazon.com/cloudwatch/home?region={event_region}#logEventViewer:group=/aws/batch/job;stream={batch_job_definition_short_name}/default/{batch_job_id}",
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
                        "value": aws_account,
                        "short": True
                    }
                ],
                "footer": "AWS Batch Job",
                "ts": batch_job_ts
            }
        ]

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

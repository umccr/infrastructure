import os
import json
import http.client

slack_host = os.environ.get("SLACK_HOST")
slack_webhook_endpoint = os.environ.get("SLACK_WEBHOOK_ENDPOINT")
slack_channel = os.environ.get("SLACK_CHANNEL")
headers = {
    'Content-Type': 'application/json',
}


def call_slack_webhook(topic, title, message, sender='Notice from AWS'):
    connection = http.client.HTTPSConnection(slack_host)

    # TODO: make more generic/customisable
    post_data = {
        "channel": slack_channel,
        "username": sender,
        "text": "*" + topic + "*",
        "icon_emoji": ":aws_logo:",
        "attachments": [{
            "title": title,
            "text": message
        }]
    }

    connection.request("POST", slack_webhook_endpoint, json.dumps(post_data), headers)
    response = connection.getresponse()
    connection.close()

    return response.status


def lambda_handler(event, context):
    # Log the received event
    print(f"Received event: {json.dumps(event, indent=2)}")

    # set Slack message defaults in case we cannot extract more meaningful data
    # at least this should produce a Slack notification we can follow up on
    slack_sender = ""
    slack_topic = "Unknown"
    slack_title = "Unknown"
    slack_message = "Unknown"

    # check what kind of event we have recieved
    if event.get('topic'):
        # Custom event for Slack
        print("Custom Slack event")
        slack_topic = event['topic']
        slack_title = event['title'] if event.get('title') else ""
        slack_message = event['message'] if event.get('message') else ""
    elif event.get('Records'):
        # SNS notification
        print("Received event records. Looking at first record only")
        record = event['Records'][0]  # assume we only have one record TODO: check for situations where we can have more
        if record.get('EventSource') or record.get('eventSource'):
            slack_sender = f"Message from {record['EventSource']}{record['eventSource']}"
        if record.get('Sns'):
            print("Extracted SNS record")
            sns_record = record.get('Sns')
            topic_arn = sns_record['TopicArn'] if sns_record.get('TopicArn') else ""
            slack_topic = f"SNS topic: {topic_arn}"
            if sns_record.get('Message'):
                print(f"Message: {sns_record['Message']}")
                message = json.loads(sns_record['Message'])
                if message.get('AlarmName'):
                    slack_title = f"Alarm {message['AlarmName']} changed to {message['NewStateValue']}"
                    slack_message = message['AlarmDescription'] if message.get('AlarmDescription') else ""
                elif 'Stratus' in topic_arn:
                    # There can be GDS and TES notifications
                    # TODO: check differences between notifcations
                    slack_title = message['name'] if message.get('name') else ""
                    stratus_status = message['status'] if message.get('status') else ""
                    stratus_type = sns_record['MessageAttributes']['type']['Value']
                    stratus_action = sns_record['MessageAttributes']['action']['Value']
                    slack_message = F"A {stratus_type} was {stratus_action}"
                    if stratus_status:
                        slack_message += f": Status {stratus_status}"
                else:
                    slack_message = "Unrecognised SNS notification format"
            else:
                print("SNS record does not seem to contain a message")
        elif record.get('s3'):
            print("Got S3 event")
        else:
            print("No 'Sns' record found")
    elif event.get('source'):
        print("Regular CloudWatch event")
        # Regular AWS event, need to extract useful information
        event_source = event['source']
        event_detail_type = event['detail-type'] if event.get('detail-type') else ""
        event_id = event['id'] if event.get('id') else ""
        event_account = event['account'] if event.get('account') else ""
        event_resources = event['resources'] if event.get('resources') else []
        event_resources_names = []
        for event_res in event_resources:
            event_resources_names.append(event_res.rpartition(":")[2])
        slack_topic = f"AWS event from {event_source} in account {event_account}"
        slack_title = f"{event_detail_type} (id:{event_id}) for {event_resources_names}"
        # event details are event specific, we just dump them into the message
        slack_message = json.dumps(event['detail'])
    else:
        slack_topic = "Unknown event source"
        slack_title = "Don't know how to handle this event"
        slack_message = json.dumps(event, indent=2)

    # Forward the data to Slack
    try:
        print(f"Sending Slack message with topic ({slack_topic}), title ({slack_title}) and message ({slack_message})")
        if slack_sender != "":
            response = call_slack_webhook(slack_topic, slack_title, slack_message, slack_sender)
        else:
            response = call_slack_webhook(slack_topic, slack_title, slack_message)
        print(f"Response status: {response}")
        return event

    except Exception as e:
        print(e)

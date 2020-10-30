import os
import json
import http.client
import boto3

iam_client = boto3.client('iam')

slack_host = os.environ.get("SLACK_HOST")
slack_webhook_endpoint = os.environ.get("SLACK_WEBHOOK_ENDPOINT")
slack_channel = os.environ.get("SLACK_CHANNEL")
headers = {
    'Content-Type': 'application/json',
}


def call_slack_webhook(topic, title, message):
    connection = http.client.HTTPSConnection(slack_host)

    # TODO: make more generic/customisable
    post_data = {
        "channel": slack_channel,
        "username": "Notice from AWS",
        "text": "*" + topic + "*",
        "icon_emoji": ":aws:",  # TODO: change to aws-logo, as :aws: appears in ARNs
        "attachments": [{
            "title": title,
            "text": message
        }]
    }

    connection.request("POST", slack_webhook_endpoint, json.dumps(post_data), headers)
    response = connection.getresponse()
    connection.close()

    return response.status


def get_username_from_userid(user_id):
    user_response = iam_client.list_users()
    for user in user_response['Users']:
        if user['UserId'] == user_id:
            return user['UserName']
    return None


def lambda_handler(event, context):
    # Log the received event
    print(f"Received event: {json.dumps(event, indent=2)}")

    # set Slack message defaults in case we cannot extract more meaningful data
    # at least this should produce a Slack notification we can follow up on
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
        if record.get('Sns'):
            print("Extracted SNS record")
            event_source = record.get('EventSource')
            slack_topic = f"Message from {event_source}"
            sns_record = record.get('Sns')
            if sns_record.get('Message'):
                print(f"Message: {sns_record['Message']}")
                message = json.loads(sns_record['Message'])
                # Can have all sorts of messages here....
                if message.get('AlarmName'):
                    slack_title = message['AlarmName']
                    slack_title += message['NewStateValue']
                    slack_message = message['AlarmDescription']
                elif message.get('Records'):
                    msg_record = message['Records'][0]  # Only consider first record for now
                    if msg_record.get('eventSource'):
                        if msg_record['eventSource'] == 'aws:s3' and msg_record.get('userIdentity'):
                            principal_id = msg_record['userIdentity']['principalId']
                            if principal_id.startswith('AWS:'):
                                user_id = principal_id[4:]
                                print(f"User ID: {user_id}")
                                user_name = get_username_from_userid(user_id)
                        slack_title = f"Event: {msg_record['eventSource']} {msg_record['eventName']}"
                        if msg_record.get('s3'):
                            slack_message = msg_record['s3']['bucket']['name']
                            slack_message += " : "
                            slack_message += msg_record['s3']['object']['key']
                        if user_name:
                            slack_message += f" (submitter: {user_name})"
                else:
                    slack_title = "Unknown SNS message format"
            else:
                print("SNS record does not seem to contain a message")
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
        msg_tmp = event['detail'] if event.get('detail') else event['Message']
        slack_message = json.dumps(msg_tmp)
    else:
        slack_topic = "Unknown event source"
        slack_title = "Don't know how to handle this event"
        slack_message = json.dumps(event, indent=2)

    # Forward the data to Slack
    try:
        print(f"Sending Slack message with topic ({slack_topic}), title ({slack_title}) and message ({slack_message})")
        response = call_slack_webhook(slack_topic, slack_title, slack_message)
        print(f"Response status: {response}")
        return event

    except Exception as e:
        print(e)

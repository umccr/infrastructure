import os
import json
import http.client

slack_host = os.environ.get("SLACK_HOST")
slack_webhook_endpoint = os.environ.get("SLACK_WEBHOOK_ENDPOINT")
slack_channel = os.environ.get("SLACK_CHANNEL")
headers = {
    'Content-Type': 'application/json',
}


def call_slack_webhook(topic, title, message):
    connection = http.client.HTTPSConnection(slack_host)

    post_data = {
        "channel": slack_channel,
        "username": "Notice from AWS",
        "text": "*" + topic + "*",
        "icon_emoji": ":aws:",
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
    print("Received event: {}".format(json.dumps(event, indent=2)))

    # we may have a custom event that delivers directly the topic/title/message to send to Slack
    if event.get('topic'):
        print("Custom Slack event")
        slack_topic = event['topic']
        slack_title = event['title'] if event.get('title') else ""
        slack_message = event['message'] if event.get('message') else ""
    else:
        print("Regular AWS event")
        # Regular AWS event, need to extract useful information
        event_source = event['source'] if event.get('source') else ""
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

    # Forward the data to Slack
    try:
        response = call_slack_webhook(slack_topic, slack_title, slack_message)
        print("Response status: {}".format(response))
        return event

    except Exception as e:
        print(e)

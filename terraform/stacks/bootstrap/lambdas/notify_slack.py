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
    print("Slack host: {}".format(slack_host))
    print("Slack webhook endpoint: {}".format(slack_webhook_endpoint[:-10]))

    slack_message_topic = event['topic'] if event.get('topic') else "No topic"
    slack_message_title = event['title'] if event.get('title') else "No title"
    slack_message = event['message'] if event.get('message') else "No message"
    print("Slack message topic: {}".format(slack_message_topic))
    print("Slack message title: {}".format(slack_message_title))
    print("Slack message: {}".format(slack_message))

    try:
        response = call_slack_webhook(slack_message_topic, slack_message_title, slack_message)
        print("Response status: {}".format(response))
        return event

    except Exception as e:
        print(e)

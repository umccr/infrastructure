import os
import json
from typing import Any

import boto3
import http.client


def get_aws_account_name(id):
    if id == "472057503814":
        return "prod"
    elif id == "843407916570":
        return "dev"
    elif id == "620123204273":
        return "dev (old)"
    elif id == "602836945884":
        return "agha"
    else:
        return id


def get_ssm_param_value(name: str) -> str:
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    ssm_client = boto3.client("ssm")

    return ssm_client.get_parameter(Name=name, WithDecryption=True)["Parameter"][
        "Value"
    ]


def call_slack_webhook(slack_host: str, slack_webhook_ssm_name: str, message: any):
    slack_webhook_endpoint = "/services/" + get_ssm_param_value(slack_webhook_ssm_name)

    connection = http.client.HTTPSConnection(slack_host)

    connection.request(
        "POST",
        slack_webhook_endpoint,
        json.dumps(message),
        {
            "Content-Type": "application/json",
        },
    )
    response = connection.getresponse()
    connection.close()

    return response.status


def send_secrets_event_to_slack(
    event: Any, slack_host: str, slack_webhook_ssm_name: str, slack_channel: str
) -> None:
    """
    Print the details of a SecretsManager event to Slack.

    Args:
        event: the event we are logging to Slack
        slack_host: the hostname of the Slack hook
        slack_webhook_ssm_name: the SSM parameter name that holds the secret id for our webhook
        slack_channel: the channel name we want to message to go to
    """
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")

    # we expect events of a defined format so if not matching we must abort
    if event.get("source") != "aws.secretsmanager":
        raise ValueError("Unexpected event format!")

    print("Processing SecretsManager event...")

    try:
        if event.get("detail-type") == "AWS Service Event via CloudTrail":
            response = call_slack_webhook(
                slack_host,
                slack_webhook_ssm_name,
                event_as_slack_message(event, slack_channel),
            )

            print(f"Response status: {response}")
            return event

    except Exception as e:
        print(e)


def event_as_slack_message(event: Any, slack_channel: str) -> Any:
    """
    Convert the given AWS event for Secrets Manager into a message packet we can send to Slack.

    Args:
        event:
        slack_channel:

    Returns:

    """

    # {
    #     "version": "0",
    #     "id": "d82e0a2d-f36e-11fd-37cb-cba423a71196",
    #     "detail-type": "AWS Service Event via CloudTrail",
    #     "source": "aws.secretsmanager",
    #     "account": "843407916570",
    #     "time": "2021-09-01T00:50:20Z",
    #     "region": "ap-southeast-2",
    #     "resources": [],
    #     "detail": {
    #         "eventVersion": "1.08",
    #         "userIdentity": {
    #             "accountId": "843407916570",
    #             "invokedBy": "secretsmanager.amazonaws.com"
    #         },
    #         "eventTime": "2021-09-01T00:50:20Z",
    #         "eventSource": "secretsmanager.amazonaws.com",
    #         "eventName": "RotationFailed",
    #         "awsRegion": "ap-southeast-2",
    #         "sourceIPAddress": "secretsmanager.amazonaws.com",
    #         "userAgent": "secretsmanager.amazonaws.com",
    #         "errorMessage": "Error when executing lambda arn:aws:lambda:ap-southeast-2:84...G9DQfx6 during createSecret step",
    #         "requestParameters": null,
    #         "responseElements": null,
    #         "additionalEventData": {
    #             "SecretId": "arn:aws:secretsmanager:ap-southeast-2:843407916570:secret:IcaS...icA"
    #         },
    #         "requestID": "Rotation-arn:aws:secretsmanager:ap-southeast-2:84340791...980c9c",
    #         "eventID": "e3b69cfe-b70e-4c94-baa9-9decc3c150b9",
    #         "readOnly": false,
    #         "eventType": "AwsServiceEvent",
    #         "managementEvent": true,
    #         "recipientAccountId": "843407916570",
    #         "eventCategory": "Management"
    #     }
    # }

    event_detail = event.get("detail")
    event_region = event.get("region")
    event_name = event.get("eventName")
    aws_account = event.get("account")
    aws_account_name = get_aws_account_name(aws_account)
    additional_event_data = event_detail.get("additionalEventData")

    if additional_event_data:
        secret_id = additional_event_data.get("SecretId")
    else:
        secret_id = "unknown:secret:arn"

    msg = {
        "channel": slack_channel,
        "icon_emoji": ":aws_logo:",
        "username": "AWS SecretsManager",
    }

    if event_name == "RotationFailed":
        msg["text"] = (
            f"❌ Periodic JWT key generation *failed* in `{aws_account_name}` for secret `{secret_id}`",
        )
    elif event_name == "RotationSucceeded":
        msg["text"] = (
            f"✅ Periodic JWT key generation *succeeded* in `{aws_account_name}` for secret `{secret_id}`",
        )
    else:
        msg["text"] = (
            f"? Unknown event in `{aws_account_name}` for secret `{secret_id}`",
        )

    return msg

    #         "blocks": [
    #             {
    #                 "type": "header",
    #                 "text": {
    #                     "type": "plain_text",
    #                     "text": "New request"
    #                 }
    #             },
    #             {
    #                 "type": "section",
    #                 "fields": [
    #                     {
    #                         "type": "mrkdwn",
    #                         "text": "*Type:*\nPaid Time Off"
    #                     },
    #                     {
    #                         "type": "mrkdwn",
    #                         "text": "*Created by:*\n<example.com|Fred Enriquez>"
    #                     }
    #                 ]
    #             },
    #             {
    #                 "type": "section",
    #                 "fields": [
    #                     {
    #                         "type": "mrkdwn",
    #                         "text": "*When:*\nAug 10 - Aug 13"
    #                     }
    #                 ]
    #             },
    #             {
    #                 "type": "section",
    #                 "text": {
    #                     "type": "mrkdwn",
    #                     "text": "<https://example.com|View request>"
    #                 }
    #             }
    #         ]

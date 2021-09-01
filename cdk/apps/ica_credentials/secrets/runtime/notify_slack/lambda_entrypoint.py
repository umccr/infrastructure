import os
from typing import Any

from notify_slack import send_secrets_event_to_slack


def main(ev: Any, context: Any) -> Any:
    """
    """
    print(f"Starting slack notifier for Secrets Manager")

    slack_host = os.environ["SLACK_HOST"]

    if not slack_host:
        raise Exception("SLACK_HOST must be specified in the Notify Slack lambda environment")

    slack_webhook_ssm_name = os.environ["SLACK_WEBHOOK_SSM_NAME"]

    if not slack_webhook_ssm_name:
        raise Exception("SLACK_WEBHOOK_SSM_NAME must be specified in the Notify Slack lambda environment")

    slack_channel = os.environ["SLACK_CHANNEL"]

    if not slack_channel:
        raise Exception("SLACK_CHANNEL must be specified in the Notify Slack lambda environment")

    send_secrets_event_to_slack(ev, slack_host, slack_webhook_ssm_name, slack_channel)

import os
from datetime import datetime, timezone
from typing import Any

from .notify_slack import send_secrets_event_to_slack


def main(ev: Any, _: Any) -> Any:
    """
    Send a notification to Slack for an event that occurred in Secrets Manager
    """
    print(f"Starting slack notifier for Secrets Manager")

    slack_host_ssm_name = os.environ["SLACK_HOST_SSM_NAME"]

    if not slack_host_ssm_name:
        raise Exception(
            "SLACK_HOST_SSM_NAME must be specified in the Notify Slack lambda environment"
        )

    slack_webhook_ssm_name = os.environ["SLACK_WEBHOOK_SSM_NAME"]

    if not slack_webhook_ssm_name:
        raise Exception(
            "SLACK_WEBHOOK_SSM_NAME must be specified in the Notify Slack lambda environment"
        )

    # to avoid massive Slack spam - we chose to only actually display a message
    # on limited days and time windows
    n = datetime.now(timezone.utc)

    # only message in the first half of the day on the first day of the week (UTC!)
    # obviously the rotation cron schedules must in some way match up so that this window is used
    if n.isoweekday() == 1:
        if n.hour < 12:
            send_secrets_event_to_slack(ev, slack_host_ssm_name, slack_webhook_ssm_name)

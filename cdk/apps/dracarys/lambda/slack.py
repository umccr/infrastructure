import logging
from libumccr import libslack
from datetime import datetime

# Slack badge and footer
SLACK_SENDER_BADGE_DRACARYS = "Dracarys"
SLACK_SENDER_FOOTER_DRACARYS = "GDS to DataBricks data ingestion lambda"

def handler(event, context):
    gds_input = event["Records"][0]["messageAttributes"]["gds_input"]
    notify_dracarys_status('Failed', gds_input)

def notify_dracarys_status(status: str, data_object_path: str):
    """ Notifies (mainly failed) ingestion data objects by the Dracarys ingestion lambda
        :param status: Dracarys run status
        :data_object: GDS path to the file that failed processing
    """

    sender = SLACK_SENDER_BADGE_DRACARYS
    if status == 'Failed':
        slack_color = libslack.SlackColor.RED.value
    else:
        logging.info(f"Unsupported status {status}. Not reporting to Slack!")
        return

    topic = f"Dracarys"
    attachments = [{
        "fallback": f"Run {status} on {data_object_path}",
        "color": slack_color,
        "pretext": "Dracarys",
        "title": f"Run {status} on {data_object_path}",
        "text": data_object_path,
        "fields": [
            {
                "title": "Status",
                "value": status,
                "short": True
            },
            {
                "title": "Object",
                "value": data_object_path,
                "short": True
            },
        ],
        "footer": SLACK_SENDER_FOOTER_DRACARYS,
        "ts": datetime.now()
    }]

    return libslack.call_slack_webhook(sender, topic, attachments)
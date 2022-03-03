import json
import eb_util as util


def is_report(event):
    return True


def handler(event, context):
    # Log the received event in CloudWatch
    print("Starting GDS event handler")
    print(f"Received event: {json.dumps(event)}")

    print("converting SQS-ENS-GDS event into Data Portal GDS event")

    object_key = event.get('object_key', "test-file.txt")
    payload = {
        "volume": "test-volume",
        "name": object_key
    }

    util.send_event_to_bus(
        event_type=util.EventType.FSC,
        event_source=util.EventSource.GDS,
        event_payload=payload)

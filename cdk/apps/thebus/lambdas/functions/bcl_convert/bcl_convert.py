import json
from eb_util import send_event_to_bus, EventType, EventSource, BusEventKey


def handler(event, context):
    # Log the received event in CloudWatch
    print("Starting bcl_convert handler")
    print(f"Received event: {json.dumps(event)}")

    payload = event.get(BusEventKey.DETAIL.value)

    print(f"Emitting {EventType.BCL_CONVERT} event")
    # mock: just forward on the payload
    send_event_to_bus(event_type=EventType.WES_LAUNCH,
                      event_source=EventSource.BCL_CONVERT,
                      event_payload=payload)

    print("All done.")

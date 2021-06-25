from datetime import datetime
from enum import Enum
import boto3

event_bus = boto3.client('events')


class EventSource(Enum):
    ORCHESTRATOR = "ORCHESTRATOR"


class EventType(Enum):
    BCL_CONVERT = "BCL_CONVERT"


def send_event_to_bus(bus_name: str,
                      event_source: EventSource,
                      event_type: EventType,
                      event_payload: dict) -> dict:

    response = event_bus.put_events(
        Entries=[
            {
                'Time': datetime(datetime.utcnow()),
                'Source': event_source.value,
                'Resources': [],
                'DetailType': event_type,
                'Detail': event_payload,
                'EventBusName': bus_name
            },
        ]
    )

    return response

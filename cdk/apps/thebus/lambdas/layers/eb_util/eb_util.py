import os
import boto3
import time
import json
from enum import Enum

event_bus = boto3.client('events')
event_bus_name = os.environ.get("EVENT_BUS_NAME")


class BusEventKey(Enum):
    DETAIL_TYPE = 'detail-type'
    DETAIL = 'detail'
    ID = 'id'
    version = 'version'
    SOURCE = 'source'
    ACCOUNT = 'account'
    time = 'time'
    region = 'region'
    resources = 'resources'

    def __str__(self):
        return self.value

    def __repr__(self):
        return f"BusEventKey.{self}"


class EventSource(Enum):
    GDS = "GDS"
    WES = "WES"
    BSSH = "BSSH"
    ORCHESTRATOR = "ORCHESTRATOR"
    BCL_CONVERT = "BCL_CONVERT"
    DRAGEN_WGS_QC = "DRAGEN_WGS_QC"
    DRAGEN_WGS_SOMATIC = "DRAGEN_WGS_SOMATIC"

    def __str__(self):
        return self.value

    def __repr__(self):
        return f"EventSource.{self}"


class EventType(Enum):
    BSSH = "BSSH"
    GDS = "GDS"
    S3 = "S3"
    WES = "WES"
    BCL_CONVERT = "BCL_CONVERT"
    DRAGEN_WGS_QC = "DRAGEN_WGS_QC"
    DRAGEN_WGS_SOMATIC = "DRAGEN_WGS_SOMATIC"
    WES_LAUNCH = "WES_LAUNCH"

    def __str__(self):
        return self.value

    def __repr__(self):
        return f"EventType.{self}"


def send_event_to_bus(event_source: EventSource,
                      event_type: EventType,
                      event_payload) -> dict:

    # TODO: figure out best timestamp handling
    response = event_bus.put_events(
        Entries=[
            {
                'Time': time.time(),
                'Source': event_source.value,
                'Resources': [],
                'DetailType': event_type.value,
                'Detail': json.dumps(event_payload),
                'EventBusName': event_bus_name
            },
        ]
    )

    return response


def emit_event(event) -> dict:
    return event_bus.put_events(Entries=[event])

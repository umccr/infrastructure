import json
import time
from eb_util import send_event_to_bus, EventType, EventSource
# from sequencerunstatuschange import Event as SRSCEvent
# from sequencerunstatuschange import Marshaller as SRSCMarshaller

# TODO: split into separate lambdas? each responsible for s specific ENS event type, each with it's own ENS subscription


def is_wes_event(event):
    return event.get('type', "unknown") == EventType.WES.value


def is_bssh_event(event):
    return event.get('type', "unknown") == EventType.BSSH.value


def is_gds_event(event):
    return event.get('type', "unknown") == EventType.GDS.value


def handle_bssh_event(event):
    payload = {
        "seq_run_name": event.get("seq_run_name", "210630_A01052_0900_AH4KMDSSXY"),
        "seq_run_id": event.get("seq_run_id", "r.MK8wf6UUn02VQba98Yw2eG"),
        "status": "UPLOAD_COMPLETE"
    }
    send_event_to_bus(event_type=EventType.BDDH,
                      event_source=EventSource.BSSH,
                      event_payload=payload)


def handle_wes_event(event):
    payload = {
        "workflow_name": event.get("workflow_name", "bcl_convert_workflow_fake_name"),
        "workflow_data": event.get("workflow_data", "fake_workflow_data"),
        "workflow_state": event.get("workflow_state", "SUCCEEDED")
    }
    send_event_to_bus(event_type=EventType.WES,
                      event_source=EventSource.WES,
                      event_payload=payload)


def handle_gds_event(event):
    payload = {
        "volume": event.get("volume", "fake_volume"),
        "object_key": event.get("object_key", "fake/object/key.txt")
    }
    send_event_to_bus(event_type=EventType.GDS,
                      event_source=EventSource.GDS,
                      event_payload=payload)


# def handle_bssh_event(event):
#     payload = SRSCEvent(
#         sequence_run_name=event.get("seq_run_name", "fake-seq-run-name"),
#         sequence_run_id=event.get("seq_run_id", "fake-seq-run-id"),
#         status=event.get("status", "UPLOAD_COMPLETE"),
#         timestamp=time.time())
#     print(f"Emitting event with payload {payload}")
#     send_event_to_bus(event_type=EventType.BSSH,
#                       event_source=EventSource.BSSH,
#                       event_payload=payload)


def handle_bssh_event(event):
    payload = {
        "seq_run_name": event.get("seq_run_name", "fake-seq-run-name"),
        "seq_run_id": event.get("seq_run_id", "fake-seq-run-id"),
        "status": event.get("status", "UPLOAD_COMPLETE")
    }
    print(f"Emitting event with payload {payload}")
    send_event_to_bus(event_type=EventType.BSSH,
                      event_source=EventSource.BSSH,
                      event_payload=payload)


def handler(event, context):
    # Log the received event in CloudWatch
    print("Starting ens_event_manager")
    print(f"Received event: {json.dumps(event)}")

    print("Emitting event to event bus")

    if is_wes_event(event):
        handle_wes_event(event)
    elif is_bssh_event(event):
        handle_bssh_event(event)
    elif is_gds_event(event):
        handle_gds_event(event)
    else:
        # TODO error out
        raise ValueError(f"Unsupported event! Expected WES/BSSH/GDS event, got: {event}")

    print("All done.")
#
#
# payload = SRSCEvent(
#     sequence_run_name="fake-seq-run-name",
#     sequence_run_id="fake-seq-run-id",
#     status="UPLOAD_COMPLETE",
#     timestamp=1624933814.26719)
#
# print(SRSCMarshaller.marshall(payload))
#
# foo = '{"sequence_run_id": "fake-seq-run-id", "sequence_run_name": "fake-seq-run-name", "status": "UPLOAD_COMPLETE", "timestamp": 1624933814.26719}'
#
# payload2: SRSCEvent = SRSCMarshaller.unmarshall(json.loads(foo), typeName=SRSCEvent)
# print(isinstance(payload2, SRSCEvent))
# print(payload2)
# print(SRSCMarshaller.marshall(payload2))
# print(payload2.sequence_run_id)
#

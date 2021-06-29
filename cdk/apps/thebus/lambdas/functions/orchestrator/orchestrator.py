import json
from eb_util import send_event_to_bus, EventType, EventSource, BusEventKey


def is_wes_event(event):
    return event.get(BusEventKey.DETAIL_TYPE.value, "") == EventType.WES.value


def is_bssh_event(event):
    return event.get(BusEventKey.DETAIL_TYPE.value, "") == EventType.BSSH.value


def is_bcl_convert_event(event):
    payload = event.get(BusEventKey.DETAIL.value)
    if not payload:
        raise ValueError("No event payload!")
    return payload.get("workflow_name").startswith("bcl_convert_workflow")


def handle_bcl_convert_event(event):
    # Trigger a WGS QC run for all WGS libraries

    # mock
    for i in (1, 2, 3, 4):
        payload = {
            "library_id": f"L21000{i}"
        }
        send_event_to_bus(event_source=EventSource.ORCHESTRATOR,
                          event_type=EventType.DRAGEN_WGS_QC,
                          event_payload=payload)


def is_dragen_wgs_qc_event(event):
    payload = event.get(BusEventKey.DETAIL.value)
    if not payload:
        raise ValueError("No event payload!")
    return payload.get("workflow_name").startswith("dragen_wgs_qc_workflow")


def handle_dragen_wgs_qc_event(event):
    # Retrieve and store yield/qc values, update library status
    # Trigger somatic workflow (if possible)

    # mock
    for i in (1, 2, 3):
        payload = {
            "library_id_normal": f"L21000{i}",
            "library_id_tumor": f"L21001{i}"
        }
        send_event_to_bus(event_source=EventSource.ORCHESTRATOR,
                          event_type=EventType.DRAGEN_WGS_SOMATIC,
                          event_payload=payload)


def is_dragen_wgs_somatic_event(event):
    payload = event.get(BusEventKey.DETAIL.value)
    if not payload:
        raise ValueError("No event payload!")
    return payload.get("workflow_name").startswith("dragen_wgs_somatic_workflow")


def handle_dragen_wgs_somatic_event(event):
    # Trigger post processing
    pass


def handle_bssh_event(event):
    payload = event.get("detail", {})

    if payload.get("status") == "UPLOAD_COMPLETE":
        print(f"Emitting event with payload {payload}")
        send_event_to_bus(event_source=EventSource.ORCHESTRATOR,
                          event_type=EventType.BCL_CONVERT,
                          event_payload=payload)
    # ignore other BSSH events


def handler(event, context):
    # Log the received event in CloudWatch
    print("Starting orchestratr handler")
    print(f"Received event: {json.dumps(event)}")

    if is_wes_event(event):
        if is_bcl_convert_event(event):
            handle_bcl_convert_event(event)
        elif is_dragen_wgs_qc_event(event):
            handle_dragen_wgs_qc_event(event)
        elif is_dragen_wgs_somatic_event(event):
            handle_dragen_wgs_somatic_event(event)
        else:
            raise ValueError(f"Unsupported workflow/event type: {event}")
    elif is_bssh_event(event):
        handle_bssh_event(event)
    else:
        raise ValueError(f"Unsupported event type: {event.get('detail-type')}")


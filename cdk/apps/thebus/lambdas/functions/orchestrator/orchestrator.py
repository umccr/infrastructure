import json
import eb_util as util
import schema.workflowrequest as wfr
import schema.sequencerunstatechange as srsc

from schema.sequencerunstatechange import Event as SEvent

def is_wes_event(event):
    return event.get(util.BusEventKey.DETAIL_TYPE.value, "") == util.EventType.WES.value


def is_srsc_event(event):
    return event.get(util.BusEventKey.DETAIL_TYPE.value) == util.EventType.SRSC.value


def is_bcl_convert_event(event):
    payload = event.get(util.BusEventKey.DETAIL.value)
    if not payload:
        raise ValueError("No event payload!")
    return payload.get("workflow_name").startswith(util.WorkflowType.BCL_CONVERT.value)


def handle_bcl_convert_event(event):
    # Trigger a WGS QC run for all WGS libraries

    # mock
    for i in (1, 2, 3, 4):
        payload = {
            "library_id": f"L21000{i}"
        }
        util.send_event_to_bus(
            event_source=util.EventSource.ORCHESTRATOR,
            event_type=util.EventType.DRAGEN_WGS_QC,
            event_payload=payload)


def is_dragen_wgs_qc_event(event):
    payload = event.get(util.BusEventKey.DETAIL.value)
    if not payload:
        raise ValueError("No event payload!")
    return payload.get("workflow_name").startswith(util.WorkflowType.DRAGEN_WGS_QC.value)


def handle_dragen_wgs_qc_event(event):
    # Retrieve and store yield/qc values, update library status
    # Trigger somatic workflow (if possible)

    # mock
    for i in (1, 2, 3):
        payload = {
            "library_id_normal": f"L21000{i}",
            "library_id_tumor": f"L21001{i}"
        }
        util.send_event_to_bus(
            event_source=util.EventSource.ORCHESTRATOR,
            event_type=util.EventType.DRAGEN_WGS_SOMATIC,
            event_payload=payload)


def is_dragen_wgs_somatic_event(event):
    payload = event.get(util.BusEventKey.DETAIL.value)
    if not payload:
        raise ValueError("No event payload!")
    return payload.get("workflow_name").startswith(util.WorkflowType.DRAGEN_WGS_SOMATIC.value)


def handle_dragen_wgs_somatic_event(event):
    # Trigger post processing
    pass


def handle_srsc_event(event):
    event_type = event.get(util.BusEventKey.DETAIL_TYPE.value)
    if event_type != util.EventType.SRSC.value:
        raise ValueError(f"Unsupported event type: {event_type}")
    payload = event.get(util.BusEventKey.DETAIL.value)
    # srsc_event: srsc.Event = srsc.Marshaller.unmarshall(json.loads(payload), typeName=srsc.Event)
    # if srsc_event.status == "PendingAnalysis":
    if payload.get("status") == "PendingAnalysis":
        print(f"Emitting event with payload {payload}")
        util.send_event_to_bus(
            event_source=util.EventSource.ORCHESTRATOR,
            event_type=util.EventType.SRSC,
            event_payload=payload)
    # ignore other SequenceRunStateChange events


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
    elif is_srsc_event(event):
        handle_srsc_event(event)
    else:
        raise ValueError(f"Unsupported event type: {event.get('detail-type')}")


# from datetime import datetime
# ev = srsc.Event(
#     sequence_run_name="sname",
#     sequence_run_id="sid",
#     gds_volume_name='gdsname',
#     gds_folder_path="gdspath",
#     status="ready",
#     timestamp=datetime.utcnow())
#
# # ev_marshalled = srsc.Marshaller.marshall(ev)
# # print('ev_marshalled')
# # print(ev_marshalled)
# # print(isinstance(ev_marshalled, str))
# # print(type(ev_marshalled))
# # ev_foo = json.dumps(ev_marshalled)
# # print(ev_foo)
# # print(isinstance(ev_foo, str))
# # obj = srsc.Marshaller.unmarshall(ev_marshalled, typeName=SEvent)
# # print(obj)
# # print(srsc.Marshaller.marshall(obj=obj))
#
# ev_string = json.dumps(ev.to_dict(), default=str)
# print('ev_string')
# print(ev_string)
# print(f"Is str? {isinstance(ev_string, str)}")
# obj: srsc.Event = srsc.Marshaller.unmarshall(json.loads(ev_string), typeName=srsc.Event)
# print(f"Is srsc.Event? {isinstance(obj, srsc.Event)}")
# print(obj)

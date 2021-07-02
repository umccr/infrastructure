import json
import logging
import eb_util as util
import schema.workflowrequest as wfr
import schema.sequencerunstatechange as srsc
import schema.workflowrunstatechange as wrsc

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# TODO: define workflow request event(s) to cater for all workflow types
# TODO: look into preventing endless/recursive loops
#       (https://theburningmonk.com/2019/06/aws-lambda-how-to-detect-and-stop-accidental-infinite-recursions/)


def is_wrsc_event(event):
    return event.get(util.BusEventKey.DETAIL_TYPE.value) == util.EventType.WRSC.value


def is_srsc_event(event):
    return event.get(util.BusEventKey.DETAIL_TYPE.value) == util.EventType.SRSC.value


def is_bcl_convert_event(event):
    payload = event.get(util.BusEventKey.DETAIL.value)
    # TODO: unmarshall full object if we only need one value?
    wrsc_event: wrsc.Event = wrsc.Marshaller.unmarshall(payload, typeName=wrsc.Event)
    wf_name: str = wrsc_event.workflow_run_name
    return wf_name.startswith(util.WorkflowType.BCL_CONVERT.value)
    # if not payload:
    #     raise ValueError("No event payload!")
    # return payload.get("workflow_run_name").startswith(util.WorkflowType.BCL_CONVERT.value)


def handle_bcl_convert_event(event):
    logger.info("Handling BCL Convert event")
    # TODO: this should be already established (remove at some point)
    event_type = event.get(util.BusEventKey.DETAIL_TYPE.value)
    if event_type != util.EventType.WRSC.value:
        raise ValueError(f"Unsupported event type: {event_type}")
    payload = event.get(util.BusEventKey.DETAIL.value)
    wrsc_event: wrsc.Event = wrsc.Marshaller.unmarshall(payload, typeName=wrsc.Event)

    if wrsc_event.status == "Succeeded":
        # trigger WGS QC events (mock 4 events)
        for i in (1, 2, 3, 4):
            wfr_event = wfr.Event(
                library_id=f"L21000{i}"
            )
            logger.info(f"Emitting DRAGEN_WGS_QC event with payload {wfr_event}")
            util.send_event_to_bus_schema(
                event_source=util.EventSource.ORCHESTRATOR,
                event_type=util.EventType.DRAGEN_WGS_QC,
                event_payload=wfr_event)
    else:
        # ignore other status for now
        logger.info(f"Received unsupported workflow status: {wrsc_event.status}")

    # Trigger a WGS QC run for all WGS libraries


def is_dragen_wgs_qc_event(event):
    payload = event.get(util.BusEventKey.DETAIL.value)
    if not payload:
        raise ValueError("No event payload!")
    return payload.get("workflow_run_name").startswith(util.WorkflowType.DRAGEN_WGS_QC.value)


def get_lib_id_from_wrsc_event(event: wrsc.Event) -> str:
    return event.workflow_run_name[-7:]


def handle_dragen_wgs_qc_event(event):
    logger.info(f"Handling {util.EventType.DRAGEN_WGS_QC} event")
    event_type = event.get(util.BusEventKey.DETAIL_TYPE.value)
    if event_type != util.EventType.WRSC.value:
        raise ValueError(f"Unsupported event type: {event_type}")
    payload = event.get(util.BusEventKey.DETAIL.value)
    wrsc_event: wrsc.Event = wrsc.Marshaller.unmarshall(payload, typeName=wrsc.Event)

    if wrsc_event.status == "Succeeded":
        logger.info(f"{util.EventType.DRAGEN_WGS_QC.value} workflow succeeded! Proceeding to T/N.")
        # only progress some libraries to mock T/N case
        lib_id = get_lib_id_from_wrsc_event(wrsc_event)
        if lib_id in ["L210001", "L210003"]:
            wfr_event = wfr.Event(
                library_id=lib_id
            )
            logger.info(f"Emitting DRAGEN_WGS_QC event with payload {wfr_event}")
            util.send_event_to_bus_schema(
                event_source=util.EventSource.ORCHESTRATOR,
                event_type=util.EventType.DRAGEN_WGS_SOMATIC,
                event_payload=wfr_event)
    else:
        # ignore other status for now
        logger.info(f"Received unsupported workflow status: {wrsc_event.status}")


def is_dragen_wgs_somatic_event(event):
    payload = event.get(util.BusEventKey.DETAIL.value)
    if not payload:
        raise ValueError("No event payload!")
    return payload.get("workflow_run_name").startswith(util.WorkflowType.DRAGEN_WGS_SOMATIC.value)


def handle_dragen_wgs_somatic_event(event):
    logger.info(f"Handling {util.EventType.DRAGEN_WGS_SOMATIC} event")
    event_type = event.get(util.BusEventKey.DETAIL_TYPE.value)
    if event_type != util.EventType.WRSC.value:
        raise ValueError(f"Unsupported event type: {event_type}")
    payload = event.get(util.BusEventKey.DETAIL.value)
    wrsc_event: wrsc.Event = wrsc.Marshaller.unmarshall(payload, typeName=wrsc.Event)

    if wrsc_event.status == "Succeeded":
        logger.info(f"{util.EventType.DRAGEN_WGS_SOMATIC} workflow succeeded! Analysis results available.")
    else:
        # ignore other status for now
        logger.info(f"Received unsupported workflow status: {wrsc_event.status}")


def handle_srsc_event(event):
    logger.info("Handling srsc event")
    event_type = event.get(util.BusEventKey.DETAIL_TYPE.value)
    if event_type != util.EventType.SRSC.value:
        raise ValueError(f"Unsupported event type: {event_type}")
    payload = event.get(util.BusEventKey.DETAIL.value)
    srsc_event: srsc.Event = srsc.Marshaller.unmarshall(payload, typeName=srsc.Event)
    # if payload.get("status") == "PendingAnalysis":
    if srsc_event.status == "PendingAnalysis":
        logger.info(f"Emitting event with payload {payload}")
        # just forward payload (no need to convert)
        util.send_event_to_bus(
            event_source=util.EventSource.ORCHESTRATOR,
            event_type=util.EventType.SRSC,
            event_payload=payload)
    # ignore other SequenceRunStateChange events


def handler(event, context):
    # Log the received event in CloudWatch
    logger.info("Starting orchestratr handler")
    logger.info(json.dumps(event))

    if is_wrsc_event(event):
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

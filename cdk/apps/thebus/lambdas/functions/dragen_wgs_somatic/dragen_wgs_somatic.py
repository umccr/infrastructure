import json
import logging
from datetime import datetime
import eb_util as util
import schema.workflowrequest as wfr
import schema.weslaunchrequest as wlr

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("Starting dragen_wgs_somatic handler")
    logger.info(json.dumps(event))

    event_type = event.get(util.BusEventKey.DETAIL_TYPE.value)
    if event_type != util.EventType.DRAGEN_WGS_SOMATIC.value:
        raise ValueError(f"Unsupported event type: {event_type}")

    payload = event.get(util.BusEventKey.DETAIL.value)
    wfr_event: wfr.Event = wfr.Marshaller.unmarshall(payload, typeName=wfr.Event)

    workflow_input = {
        "library_id_normal": wfr_event.library_id,
        "library_id_tumor": "L210999",
        "fastq_list_rows": {}
    }
    logger.info(f"Created workflow input: {workflow_input}")
    wf_name = f"{util.WorkflowType.DRAGEN_WGS_SOMATIC}_workflow_{wfr_event.library_id}"

    logger.info(f"Sending WES launch request for workflow {wf_name}")
    wes_launch_request = wlr.Event(
        workflow_run_name=wf_name,
        workflow_id="wfl.w94tygian4p8g4",
        workflow_version="3.7.5-34afe2c",
        workflow_input=workflow_input,
        timestamp=datetime.utcnow(),
        workflow_engine_parameters={}
    )

    logger.info(f"Emitting {util.EventType.WES_LAUNCH} request event: {wes_launch_request}")
    util.send_event_to_bus_schema(
        event_type=util.EventType.WES_LAUNCH,
        event_source=util.EventSource.DRAGEN_WGS_SOMATIC,
        event_payload=wes_launch_request)

    logger.info("All done.")

import json
import logging
from datetime import datetime
import eb_util as util
import schema.sequencerunstatechange as srsc
import schema.weslaunchrequest as wlr

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Lambda to prepare and trigger BCL CONVERT workflow runs.

    An event payload (detail) of the following format is expected:
    SequenceRunStateChange:
    {
        "sequence_run_name": "210525_A00100_0999_AHYYKD8MYX",
        "sequence_run_id": "r.c1IvasRL4U2MubrbB13cI4",
        'gds_volume_name': "bssh.xxxx",
        'gds_folder_path': "/Runs/210525_A00100_0999_AHYYKD8MYX_r.c1IvasRL4U2MubrbB13cI4",
        'status': "",
        'timestamp': ""
    }

    :param event: An AWSEvent with a SequenceRunStateChange event payload (detail) and SequenceRunStateChange detail-type
    :param context: Not used.
    :return:
    """
    logger.info("Starting bcl_convert handler")
    logger.info(json.dumps(event))

    event_type = event.get(util.BusEventKey.DETAIL_TYPE.value)
    if event_type != util.EventType.SRSC.value:
        raise ValueError(f"Unsupported event type: {event_type}")

    payload = event.get(util.BusEventKey.DETAIL.value)
    srsc_event: srsc.Event = srsc.Marshaller.unmarshall(payload, typeName=srsc.Event)

    workflow_input = {
        "seq_run_name": srsc_event.sequence_run_name,
        "seq_run_id": srsc_event.sequence_run_id,
        "gds_volume": srsc_event.gds_volume_name,
        "gds_path": srsc_event.gds_folder_path,
        "sample_sheet": f"gds://{srsc_event.gds_volume_name}{srsc_event.gds_folder_path}/SampleSheet.csv"
    }
    logger.info(f"Created workflow input: {workflow_input}")
    wf_name = f"{util.WorkflowType.BCL_CONVERT}_workflow_{srsc_event.sequence_run_name}_{srsc_event.sequence_run_id}"

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
    # mock: just forward on the payload
    util.send_event_to_bus_schema(
        event_type=util.EventType.WES_LAUNCH,
        event_source=util.EventSource.BCL_CONVERT,
        event_payload=wes_launch_request)

    logger.info("All done.")

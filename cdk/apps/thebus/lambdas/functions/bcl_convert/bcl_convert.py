import json
from datetime import datetime
import eb_util as util
import schema.sequencerunstatechange as srsc
import schema.weslaunchrequest as wlr


def handler(event, context):
    """
    Lambda to prepare and trigger BCL CONVERT workflow runs.

    An event of the following format is expected:
    {
        "seq_run_name": "210525_A00100_0999_AHYYKD8MYX",
        "seq_run_id": "r.c1IvasRL4U2MubrbB13cI4",
        'gds_volume_name': "bssh.xxxx",
        'gds_folder_path': "/Runs/210525_A00100_0999_AHYYKD8MYX_r.c1IvasRL4U2MubrbB13cI4"
    }

    :param event:
    :param context:
    :return:
    """
    # Log the received event in CloudWatch
    print("Starting bcl_convert handler")
    print(f"Received event: {json.dumps(event)}")

    event_type = event.get(util.BusEventKey.DETAIL_TYPE.value)
    if event_type != util.EventType.SRSC.value:
        raise ValueError(f"Unsupported event type: {event_type}")
    payload = event.get(util.BusEventKey.DETAIL.value)
    srsc_event: srsc.Event = srsc.Marshaller.unmarshall(payload, typeName=srsc.Event)

    workflow_input = {
        "seq_run_name": srsc_event.sequence_run_name,
        "seq_run_id": srsc_event.sequence_run_id,
        "gds_volume": srsc_event.gds_volume_name,
        "gds_path": srsc_event.gds_folder_path
    }
    wf_name = f"{util.WorkflowType.BCL_CONVERT}_workflow_{srsc_event.sequence_run_name}_{srsc_event.sequence_run_id}"

    wes_launch_request = wlr.Event(
        workflow_run_name=wf_name,
        workflow_id="wfl.w94tygian4p8g4",
        workflow_version="3.7.5-34afe2c",
        workflow_input=workflow_input,
        timestamp=datetime.utcnow(),
        workflow_engine_parameters={}
    )

    print(f"Emitting {util.EventType.BCL_CONVERT} event")
    # mock: just forward on the payload
    util.send_event_to_bus_schema(
        event_type=util.EventType.WES_LAUNCH,
        event_source=util.EventSource.BCL_CONVERT,
        event_payload=wes_launch_request)

    print("All done.")

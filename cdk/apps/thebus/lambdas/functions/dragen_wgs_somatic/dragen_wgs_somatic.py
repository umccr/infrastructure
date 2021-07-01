import json
import eb_util as util


def handler(event, context):
    # Log the received event in CloudWatch
    print("Starting dragen_wgs_somatic handler")
    print(f"Received event: {json.dumps(event)}")

    print(f"Emitting {util.EventType.WES_LAUNCH} event")
    payload = {
        "workflow_name": f"{util.WorkflowType.DRAGEN_WGS_QC.value}_workflow_fakesubject",
        "library_id_normal": "Lfake01",
        "library_id_tumor": "Lfake02",
        "fastq_list": "fake_fastq_list"
    }
    util.send_event_to_bus(
        event_type=util.EventType.WES_LAUNCH,
        event_source=util.EventSource.DRAGEN_WGS_SOMATIC,
        event_payload=payload)

    print("All done.")

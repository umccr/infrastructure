import json
import eb_util as util


def handler(event, context):
    # Log the received event in CloudWatch
    print("Starting dragen_wgs_qc handler")
    print(f"Received event: {json.dumps(event)}")

    print(f"Emitting {util.EventType.WES_LAUNCH} event")
    library_id = event.get('library_id', "L21fake")
    payload = {
        "workflow_name": f"{util.WorkflowType.DRAGEN_WGS_QC.value}_workflow_{library_id}",
        "library_id": library_id,
        "fastq_list": "fake_fastq_list"
    }
    util.send_event_to_bus(event_type=util.EventType.WES_LAUNCH,
                           event_source=util.EventSource.DRAGEN_WGS_QC,
                           event_payload=payload)

    print("All done.")

import json
from eb_util import send_event_to_bus, EventType, EventSource


def handler(event, context):
    # Log the received event in CloudWatch
    print("Starting dragen_wgs_qc handler")
    print(f"Received event: {json.dumps(event)}")

    print(f"Emitting {EventType.WES_LAUNCH} event")
    payload = {
        "workflow_name": "dragen_wgs_qc_Lfake01",
        "library_id": "Lfake01",
        "fastq_list": "fake_fastq_list"
    }
    send_event_to_bus(event_type=EventType.WES_LAUNCH,
                      event_source=EventSource.DRAGEN_WGS_QC,
                      event_payload=payload)

    print("All done.")

import json


def handler(event, context):
    # Log the received event in CloudWatch
    print("Handling dragen_wgs_somatic event.")
    print(f"Received event: {json.dumps(event)}")

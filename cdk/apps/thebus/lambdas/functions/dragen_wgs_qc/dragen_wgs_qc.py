import json

d

def handler(event, context):
    # Log the received event in CloudWatch
    print("Handling dragen_ags_qc event.")
    print(f"Received event: {json.dumps(event)}")

    print("Emitting WES launch event")


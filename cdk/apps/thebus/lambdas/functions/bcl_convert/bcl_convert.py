import json


def handler(event, context):
    # Log the received event in CloudWatch
    print("Handling bcl_convert event.")
    print(f"Received event: {json.dumps(event)}")

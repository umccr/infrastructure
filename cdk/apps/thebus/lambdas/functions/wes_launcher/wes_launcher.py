import json


def handler(event, context):
    # Log the received event in CloudWatch
    print("Handling wes_launcher event.")
    print(f"Received event: {json.dumps(event)}")

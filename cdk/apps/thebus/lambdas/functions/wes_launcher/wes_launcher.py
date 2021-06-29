import boto3
import json
from eb_util import BusEventKey

lambda_client = boto3.client('lambda')


def handler(event, context):
    # Log the received event in CloudWatch
    print("Starting wes_launcher lambda")
    print(f"Received event: {json.dumps(event)}")

    print("Launching fake ICA WES run")
    # TODO: fake WES/WES event for workflows (bcl_convert/qc/somatic/...)
    # call ens lambda to fake ENS event as response to workflow run

    # forward event payload to ens lambda
    payload = event.get(BusEventKey.DETAIL.value, "")
    payload['type'] = "WES"
    response = lambda_client.invoke(
        FunctionName='UmccrEventBus_ens_event_manager',  # TODO: hardcoded for mock impl
        InvocationType='Event',
        Payload=json.dumps(payload)
    )
    print(f"Lambda invocation response: {response}")

    print("All done.")

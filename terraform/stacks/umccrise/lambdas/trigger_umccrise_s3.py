import json
import boto3
import os


def lambda_handler(event, context):
    client = boto3.client('lambda')

    # environment variables
    UMCCRISE_MEM = os.environ.get("UMCCRISE_MEM")
    UMCCRISE_VCPUS = os.environ.get("UMCCRISE_VCPUS")
    UMCCRISE_FUNCTION_NAME = os.environ.get("UMCCRISE_FUNCTION_NAME")

    # event variables
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    obj = event["Records"][0]["s3"]["object"]["key"]
    data_dir = os.path.dirname(obj)
    job_name = bucket + "---" + data_dir.replace('/', '_').replace('.', '_')

    request_payload = {
         "resultDir": data_dir,
         "dataBucket": bucket,
         "memory": UMCCRISE_MEM,
         "vcpus": UMCCRISE_VCPUS,
         "jobName": job_name
    }

    # #TODO: I have no idea to put here
    # lambda_context = {
    #     "custom": {"clarkie": "wuzhere"},
    #     "env": {"ctx": "ctx"},
    #     "client": {}
    # }

    print("Invoking lambda with payload: ", request_payload)
    response = client.invoke(
        FunctionName=UMCCRISE_FUNCTION_NAME,
        InvocationType='RequestResponse',
        LogType='Tail',
        Payload=json.dumps(request_payload).encode('utf-8'),
        Qualifier='$LATEST'
    )

    if response["StatusCode"] is 200:
        message = f"Detected {obj} was uploaded to {bucket} and fired umccrise successfully."
    else:
        message = f"Detected {obj} was uploaded to {bucket} and there was an error firing umccrise."
        message += f"Error code from lambda was {response['StatusCode']}."

    print(message)

    body = {
        "message": message,
        "input": event
    }

    response = {
        "statusCode": response["StatusCode"],
        "body": json.dumps(body)
    }

    return response

import json
import boto3
import base64
import os

def lambda_handler(event, context):
    client = boto3.client('lambda')

    #environment variables
    UMCCRISE_MEM = os.environ.get("UMCCRISE_MEM")
    UMCCRISE_VCPUS = os.environ.get("UMCCRISE_VCPUS")
    UMCCRISE_FUNCTION_NAME = os.environ.get("UMCCRISE_FUNCTION_NAME")

    #event variables
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    obj = event["Records"][0]["s3"]["object"]["key"]
    data_dir = obj.split("/")[0]
    job_name = bucket + "---" + data_dir 
    
    request_payload = {
         "resultDir": data_dir, 
         "memory": UMCCRISE_MEM, 
         "vcpus": UMCCRISE_VCPUS,
         "jobName": job_name
    }

    #TODO: I have no idea to put here
    lambda_context = {
        "custom": {"clarkie": "wuzhere"},
        "env": {"ctx": "ctx"},
        "client": {}
    }
    
    print("Invoking lambda with payload: ", request_payload)
    response = client.invoke(
    FunctionName=UMCCRISE_FUNCTION_NAME,
    InvocationType='RequestResponse',
    LogType='Tail',
    ClientContext=base64.b64encode(json.dumps(lambda_context).encode('utf-8')),
    Payload=json.dumps(request_payload).encode('utf-8'),
    Qualifier='$LATEST'
)

    if response["StatusCode"] is 200:
        message = "Detected {} was uploaded to {} and fired umccrise successfully.".format(obj,bucket)
    else:
        message = "Detected {} was uploaded to {} and there was an error firing umccrise. Error code from lambda was {}".format(obj,bucket,response["StatusCode"])

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


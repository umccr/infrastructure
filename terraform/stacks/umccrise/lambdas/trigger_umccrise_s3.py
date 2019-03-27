import json
import boto3
import base64

def lambda_handler(event, context):
    client = boto3.client('lambda')

    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    obj = event["Records"][0]["s3"]["object"]["key"]
    data_dir = obj.split("/")[0]
    job_name = bucket + "---" + data_dir

    request_payload = {
         "resultDir": data_dir, 
         "memory": "50000", 
         "vcpus": "16",
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
    FunctionName='umccrise_lambda_dev',
    InvocationType='RequestResponse',
    LogType='Tail',
    ClientContext=base64.b64encode(json.dumps(lambda_context).encode('utf-8')),
    Payload=json.dumps(request_payload).encode('utf-8'),
    Qualifier='$LATEST'
)

    #TODO what if the lambda invocation fails?
    message = "Detected {} was uploaded to {} and fired umccrise successfully.".format(obj,bucket)
    print(message)

    body = {
        "message": message,
        "input": event
    }

    response = {
        "statusCode": 200,
        "body": json.dumps(body)
    }

    return response


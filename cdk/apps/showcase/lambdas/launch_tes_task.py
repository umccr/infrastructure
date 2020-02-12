import os
import json
import boto3
import http.client


IAP_API_BASE_URL = os.environ.get("IAP_API_BASE_URL")
TASK_ID = os.environ.get("TASK_ID")
TASK_VERSION = os.environ.get("TASK_VERSION")
SSM_PARAM_JWT = os.environ.get("SSM_PARAM_JWT")
IMAGE_NAME = os.environ.get("IMAGE_NAME")
IMAGE_TAG = os.environ.get("IMAGE_TAG")
GDS_LOG_FOLDER = os.environ.get('GDS_LOG_FOLDER')
TES_TASK_NAME = os.environ.get('TES_TASK_NAME')
API_ENDPOINT = f"/v1/tasks/{TASK_ID}/versions/{TASK_VERSION}:launch"
SSM_CLIENT = boto3.client('ssm')


def getSSMParam(name):
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    return SSM_CLIENT.get_parameter(
                Name=name,
                WithDecryption=True
            )['Parameter']['Value']


def send_request(method, base_url, endpoint, headers, body):
    print(f"Request body: {json.dumps(body)}")
    print(f"Establishing connection to {base_url} ...")
    conn = http.client.HTTPSConnection(host=base_url)
    print(f"Sending {method} request to {endpoint} ...")
    conn.request(method, endpoint, body=json.dumps(body), headers=headers)
    response = conn.getresponse()
    status = response.status
    print(f"Received response with status: {status}")
    print(f"Response reason: {response.reason}")
    print(f"Response msg: {response.msg}")

    data = response.read().decode('utf-8')
    print(f"Response data: {data}")

    conn.close()
    return status, data


def lambda_handler(event, context):
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")

    # extract required parameters
    task_callback_token = event.get('taskCallbackToken')
    run_id = event.get('runId')
    print(f"RUN ID: {run_id}")

    # overwrite defaults, if applicable
    image_name = event['imageName'] if event.get('imageName') else IMAGE_NAME
    image_tag = event['imageTag'] if event.get('imageTag') else IMAGE_TAG

    # API jwt_token
    jwt_token = getSSMParam(SSM_PARAM_JWT)
    print(f"Retrieved JWT token: {jwt_token[:10]}..{jwt_token[-10:]}")

    # request headers
    headers = {
        'Authorization': f"Bearer {jwt_token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    # request body
    body = {
        'name': f"SHOWCASE:{run_id}:{TES_TASK_NAME}",
        'description': task_callback_token,
        'arguments': {
            "imageName": image_name,
            "imageTag": image_tag,
            "gdsLogFolder": GDS_LOG_FOLDER,
            "runId": run_id
        }
    }

    if event.get('item'):
        body['arguments']['sample_list_name'] = event.get('item')

    # call the remote API
    status, data = send_request(
        method='POST',
        base_url=IAP_API_BASE_URL,
        endpoint=API_ENDPOINT,
        headers=headers,
        body=body)

    # finish
    return {
        'status': status,
        'message': 'All done'
    }

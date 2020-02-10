import os
import json
import boto3
import http.client


iap_base_url = os.environ.get("IAP_API_BASE_URL")
task_id = os.environ.get("TASK_ID")
task_version = os.environ.get("TASK_VERSION")
ssm_parameter_name = os.environ.get("SSM_PARAM_NAME")
default_image_name = os.environ.get("IMAGE_NAME")
default_image_tag = os.environ.get("IMAGE_TAG")
gds_log_folder = os.environ.get('GDS_LOG_FOLDER')

ssm_client = boto3.client('ssm')


def getSSMParam(name):
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    return ssm_client.get_parameter(
                Name=name,
                WithDecryption=True
            )['Parameter']['Value']


def post_to_endpoint(base_url, endpoint, headers, body):
    print(f"Request body: {json.dumps(body)}")
    print(f"Establishing connection to {base_url} ...")
    conn = http.client.HTTPSConnection(host=base_url)
    print(f"Sending request to {endpoint} ...")
    conn.request("POST", endpoint, json.dumps(body), headers=headers)
    print("Retrieving response...")
    response = conn.getresponse()
    print(f"Received response with status: {response.status}")
    print(f"Response reason: {response.reason}")
    print(f"Response msg: {response.msg}")
    conn.close()

    data = response.read()
    print(f"Response data: {data.decode('utf-8')}")

    return response.status


def lambda_handler(event, context):
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")

    # extract required parameters
    task_callback_token = event.get('taskCallbackToken')

    # overwrite defaults, if applicable
    image_name = event['imageName'] if event.get('imageName') else default_image_name
    image_tag = event['imageTag'] if event.get('imageTag') else default_image_tag
    echoParameter = event['echoParameter'] if event.get('echoParameter') else "Hello world"

    # API token
    token = getSSMParam(ssm_parameter_name)
    print(f"Retrieved JWT token: {token[:10]}..{token[-10:]}")

    # request headers
    headers = {
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    # request endpoint and body (depending on use case)
    api_url = f"/v1/tasks/{task_id}/versions/{task_version}:launch"
    body = {
        'name': "SHOWCASE",
        'description': task_callback_token,
        'arguments': {
            "imageName": image_name,
            "imageTag": image_tag,
            "gdsLogFolder": gds_log_folder,
            "echoParameter": echoParameter
        }
    }

    # call the remote API
    status = post_to_endpoint(base_url=iap_base_url, endpoint=api_url, headers=headers, body=body)

    # finish
    return {
        'status': status,
        'message': 'All done'
    }

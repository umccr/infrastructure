import os
import json
import boto3
import http.client


iap_base_url = os.environ.get("IAP_API_BASE_URL")
task_id = os.environ.get("TASK_ID")
task_version = os.environ.get("TASK_VERSION_ID")
ssm_parameter_name = os.environ.get("SSM_PARAM_NAME")
gds_default_refdata_folder = os.environ.get('GDS_REFDATA_FOLDER')
gds_output_folder = os.environ.get('GDS_OUTPUT_FOLDER')
gds_log_folder = os.environ.get('GDS_LOG_FOLDER')
default_image_name = os.environ.get("UMCCRISE_IMAGE_NAME")
default_image_tag = os.environ.get("UMCCRISE_IMAGE_TAG")

ssm_client = boto3.client('ssm')


def getSSMParam(name):
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    return ssm_client.get_parameter(
                Name=name,
                WithDecryption=True
            )['Parameter']['Value']


def call_endpoint(base_url, endpoint, headers, body):
    print(f"POST data: {json.dumps(body)}")
    print("Establishing connection...")
    conn = http.client.HTTPSConnection(host=base_url)
    print("Sending request...")
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

    if not event.get('gdsInputDataFolder'):
        return {
            'status': 'error',
            'message': 'Requried parameter gdsInputDataFolder missing'
        }

    gds_input_data_folder = event['gdsInputDataFolder']
    gds_refdata_folder = event['gdsRefDataFolder'] if event.get('gdsRefDataFolder') else gds_default_refdata_folder
    image_name = event['imageName'] if event.get('imageName') else default_image_name
    image_tag = event['imageTag'] if event.get('imageTag') else default_image_tag

    api_url = f"/v1/tasks/{task_id}/versions/{task_version}:launch"

    token = getSSMParam(ssm_parameter_name)
    print(f"Retrieved JWT token: {token[:10]}..{token[-10:]}")
    headers = {
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    body = {
        'name': 'UMCCRISE',
        'description': f"umccrise run for {gds_input_data_folder}",
        'arguments': {
            "imageName": image_name,
            "imageTag": image_tag,
            "gdsRefDataFolder": gds_refdata_folder,
            "gdsInputDataFolder": gds_input_data_folder,
            "gdsOutputFolder": gds_output_folder,
            "gdsLogFolder": gds_log_folder
        }
    }

    status = call_endpoint(base_url=iap_base_url, endpoint=api_url, headers=headers, body=body)
    print(f"Response status: {status}")

    return {
        'status': 'success',
        'message': 'All done'
    }

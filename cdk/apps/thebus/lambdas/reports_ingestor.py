import os
import json
import boto3
import http.client

iap_base_url = os.environ.get("IAP_API_BASE_URL")
ssm_parameter_name = os.environ.get("SSM_PARAM_NAME")
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

    # get mandatory reports GDS path
    if not event.get('GdsReportsDataFolder'):
        return {
            'status': 'error',
            'message': 'Required parameter GdsReportsDataFolder missing'
        }
    gds_reports_data_folder = event['GdsReportsDataFolder']
    sample_name = os.path.basename(os.path.normpath(gds_reports_data_folder))

    print(f"Extracted report name: {sample_name}")

    # API token
    token = getSSMParam(ssm_parameter_name)
    print(f"Retrieved JWT token: {token[:10]}..{token[-10:]}")

    # request headers
    headers = {
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    api_url = f"/v1/tasks/{task_id}/versions/{task_version_wgs}:launch"
    body = {
        'name': 'RNAsum',
        'description': f"RNAsum run for {sample_name} (WTS + WGS)",
        'arguments': {
            "imageName": image_name,
            "imageTag": image_tag,
            "sampleName": sample_name,
            "refDataName": refdata_name,
            "gdsWtsDataFolder": gds_wts_data_folder,
            "gdsWgsDataFolder": gds_wgs_data_folder,
            "gdsRefDataFolder": gds_refdata_folder,
            "gdsOutputFolder": gds_output_folder,
            "gdsLogFolder": gds_log_folder
        }
    }

    # call the remote API
    status = post_to_endpoint(base_url=iap_base_url, endpoint=api_url, headers=headers, body=body)

    # finish
    return {
        'status': status,
        'message': 'All done'
    }
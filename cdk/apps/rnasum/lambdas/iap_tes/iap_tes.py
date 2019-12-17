import os
import re
import json
import boto3
import http.client


iap_base_url = os.environ.get("IAP_API_BASE_URL")
task_id = os.environ.get("TASK_ID")
task_version_wts = os.environ.get("TASK_VERSION_WTS")
task_version_wgs = os.environ.get("TASK_VERSION_WGS")
ssm_parameter_name = os.environ.get("SSM_PARAM_NAME")
default_image_name = os.environ.get("RNASUM_IMAGE_NAME")
default_image_tag = os.environ.get("RNASUM_IMAGE_TAG")
gds_default_refdata_folder = os.environ.get('GDS_REFDATA_FOLDER')
gds_log_folder = os.environ.get('GDS_LOG_FOLDER')
default_refdata_name = os.environ.get('REFDATA_NAME')

ssm_client = boto3.client('ssm')
subject_pattern = re.compile("(SBJ\d{5})")


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


def get_sample_name_from_wts_folder(folder):
    return os.path.basename(os.path.normpath(folder))


def get_output_folder_from_wts_folder(folder):
    # define where in the input folder hierachy the output should be placed
    folder = folder.strip('/')
    # place output two levels up from input
    return os.path.dirname(os.path.dirname(folder))


def lambda_handler(event, context):
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")

    # get mandatory WTS GDS path
    if not event.get('gdsWtsDataFolder'):
        return {
            'status': 'error',
            'message': 'Requried parameter gdsWtsDataFolder missing'
        }
    gds_wts_data_folder = event['gdsWtsDataFolder']
    sample_name = get_sample_name_from_wts_folder(gds_wts_data_folder)
    print(f"Extracted sample name: {sample_name}")
    gds_default_output_folder = get_output_folder_from_wts_folder(gds_wts_data_folder)
    print(f"Extracted default output folder: {gds_default_output_folder}")

    # get the WGS path if present and decide whether to run WTG/WGS or WTS only
    if event.get('gdsWgsDataFolder'):
        has_wgs = True
        gds_wgs_data_folder = event['gdsWgsDataFolder']
    else:
        has_wgs = False

    # overwrite defaults, if applicable
    image_name = event['imageName'] if event.get('imageName') else default_image_name
    image_tag = event['imageTag'] if event.get('imageTag') else default_image_tag
    gds_refdata_folder = event['gdsRefDataFolder'] if event.get('gdsRefDataFolder') else gds_default_refdata_folder
    gds_output_folder = event['gdsOutputDataFolder'] if event.get('gdsOutputDataFolder') else gds_default_output_folder
    refdata_name = event['refDataName'] if event.get('gdsOutputrefDataNameDataFolder') else default_refdata_name

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
    if has_wgs:
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
    else:
        api_url = f"/v1/tasks/{task_id}/versions/{task_version_wts}:launch"
        body = {
            'name': 'RNAsum',
            'description': f"RNAsum run for {gds_wts_data_folder} (WTS only)",
            'arguments': {
                "imageName": image_name,
                "imageTag": image_tag,
                "sampleName": sample_name,
                "refDataName": refdata_name,
                "gdsWtsDataFolder": gds_wts_data_folder,
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

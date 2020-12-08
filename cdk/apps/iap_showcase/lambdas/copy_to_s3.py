import os
import json
import boto3
import http.client
import contextlib
from botocore.vendored import requests
from io import BytesIO

GDS_RUN_VOLUME = os.environ.get('umccr-run-data-dev')
S3_RUN_BUCKET = os.environ.get('umccr-run-data-dev')
IAP_BASE_URL = os.environ.get('IAP_API_BASE_URL')
SSM_PARAM_JWT = os.environ.get('SSM_PARAM_JWT')
SSM_CLIENT = boto3.client('ssm')
S3_CLIENT = boto3.client('s3')


def getSSMParam(name: str):
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    return SSM_CLIENT.get_parameter(
                Name=name,
                WithDecryption=True
            )['Parameter']['Value']


def req_to_endpoint(base_url: str, endpoint: str, headers: dict):
    print(f"baseUrl: {base_url}; endpoint: {endpoint}")
    conn = http.client.HTTPSConnection(host=base_url)
    conn.request("GET", endpoint, headers=headers)
    response = conn.getresponse()
    print(f"Response status: {response.status}")
    data = response.read()
    print(f"Response data: {data.decode('utf-8')}")
    conn.close()

    return response.status, data.decode('utf-8')


def get_report_id(run_id: str, token: str):
    # request headers
    headers = {
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    # Retrieve the FASTQ list file from GDS
    qc_files: str = f"/v1/files?volume.name={GDS_RUN_VOLUME}&path=/{run_id}/multiqc/multiqc_report.html&pageSize=2"
    status, body = req_to_endpoint(base_url=IAP_BASE_URL, endpoint=qc_files, headers=headers)

    if status == 200:
        # Extract file ID from returned JSON
        print(body)

        file_listing_json = json.loads(body)
        count = file_listing_json['itemCount']
        print(f"itemCount: {count}")

        if count == 1:
            print(f"Retrieved one MultiQC report.")
            report_id = file_listing_json['items'][0]['id']
        else:
            raise(ValueError("MultiQc report not found?"))
    else:
        raise(ValueError(f"Could not retrieve files from IAP. Status {status}"))

    print(f"Retrieved report: {report_id}")
    return report_id


def get_presigned_url(file_id: str, token: str):
    print(f"Fetching presigned URL for {file_id}")
    # request headers
    headers = {
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    # Retrieve the FASTQ list file from GDS
    file_details: str = f"/v1/files/{file_id}"
    status, body = req_to_endpoint(base_url=IAP_BASE_URL, endpoint=file_details, headers=headers)

    if status == 200:
        # Extract presignedUrl from returned JSON
        print(body)

        file_details_json = json.loads(body)
        file_presigned_url = file_details_json['presignedUrl']

    else:
        raise(ValueError(f"Could not retrieve file details from IAP. Status {status}"))

    print(f"Retrieved url: {file_presigned_url}")
    return file_presigned_url


def upload_to_s3(url: str, run_id: str):
    print(f"Uploading {url}")
    with contextlib.closing(requests.get(url, stream=True, verify=False)) as response:
        # Set up file stream from response content.
        fp = BytesIO(response.content)
        # Upload data to S3
        S3_CLIENT.upload_fileobj(fp, S3_RUN_BUCKET, 'my-dir/' + url.split('/')[-1])


def lambda_handler(event, context):
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")

    # Get run ID from input
    run_id = event['runId']

    # Get API jwt_token
    jwt_token = getSSMParam(SSM_PARAM_JWT)
    print(f"Retrieved JWT token: {jwt_token[:10]}..{jwt_token[-10:]}")

    # Retrieve the URL of the FASTA list file for the run
    report_id = get_report_id(run_id, jwt_token)

    report_presigned_url = get_presigned_url(report_id)

    upload_to_s3(report_presigned_url)

    return "success"

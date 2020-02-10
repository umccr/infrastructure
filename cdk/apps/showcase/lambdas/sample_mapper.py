import os
import csv
import json
import boto3
import http.client

# SFN task to read FASTQ list for a given sequencing run and map individual FASTQs to SampleIDs.
# Splitting a run centric FASTQ list into sample centric FASTQ pairs.

GDS_FASTQ_VOLUME = 'umccr-fastq-data-dev'
GDS_FASTQ_LIST_FILE = 'Reports/fastq_list.csv'

IAP_BASE_URL = os.environ.get("IAP_API_BASE_URL")
SSM_PARAM_NAME = os.environ.get("SSM_PARAM_NAME")
SSM_CLIENT = boto3.client('ssm')


def getSSMParam(name):
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    return SSM_CLIENT.get_parameter(
                Name=name,
                WithDecryption=True
            )['Parameter']['Value']


def parse_fastq_list(csv_gds_url):
    aws_presigned_url = "stratus-gds-aps2.s3.ap-southeast-2.amazonaws.com"
    response = req_to_endpoint(aws_presigned_url, csv_gds_url, headers={'Content-Type': 'application/json'})
    fastqs = csv.reader(response))
    yield fastqs


def req_to_endpoint(base_url, endpoint, headers):
    print(f"baseUrl: {base_url}; endpoint: {endpoint}")
    conn = http.client.HTTPSConnection(host=base_url)
    conn.request("GET", endpoint, headers=headers)
    response = conn.getresponse()
    print(f"Response status: {response.status}")
    data = response.read()
    print(f"Response data: {data.decode('utf-8')}")
    conn.close()

    return response.status, data.decode('utf-8')


def get_fastq_list(run_id: str, token: str):
    # request headers
    headers = {
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    # Retrieve the FASTQ list file from GDS
    gds_fastqs: str = f"/v1/files?volume.name={GDS_FASTQ_VOLUME}&path=/{run_id}/{GDS_FASTQ_LIST_FILE}"
    status, body = req_to_endpoint(base_url=IAP_BASE_URL, endpoint=gds_fastqs, headers=headers)

    if status == 200:
        # Extract file ID from returned JSON
        print(body)

        iap_file_list_json = json.loads(body)
        print(f"itemCount: {iap_file_list_json['itemCount']}")

        if iap_file_list_json['itemCount'] == 1:
            file_id = iap_file_list_json['items'][0]['id']
        else:
            raise(ValueError("FASTQ file list not found?"))
    else:
        raise(ValueError(f"Could not retrieve file list from IAP. Status {status}"))

    # {{baseUrl}}/v1/files/:fileId
    file_details: str = f"/v1/files/{file_id}"
    status, body = req_to_endpoint(base_url=IAP_BASE_URL, endpoint=file_details, headers=headers)

    if status == 200:
        iap_file_detail_json = json.loads(body)
        file_url = iap_file_detail_json['presignedUrl']
    else:
        raise(ValueError(f"Could not retrieve file records. Status {status}"))

    print(f"Presigned file url: {file_url}")
    return file_url


def lambda_handler(event, context):
    token = getSSMParam(SSM_PARAM_NAME)

    # XXX: Read from the API, **per run** FASTQ list from GDS
    run_id = event['run_id']
    fastq_list_url = get_fastq_list(run_id, token)

    fastq_dict = parse_fastq_list(fastq_list_url)
    # XXX: Group the FASTQs from that FASTQ list, **per sample**
    # for fastq in fastqs:
    #     print(fastq)
    # XXX: Kick off the next task, **per sample**, i.e Dragen alignment

import os
import csv
import json
import boto3
import http.client

# SFN task to read FASTQ list for a given sequencing run and map individual FASTQs to SampleIDs.
# Splitting a run centric FASTQ list into sample centric FASTQ pairs.

GDS_FASTQ_VOLUME = 'umccr-fastq-data-dev'

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


def parse_fastq_list(csv_in):
    fastqs = csv.DictReader(csv_in)
    yield fastqs


def req_to_endpoint(base_url, endpoint, headers):
    conn = http.client.HTTPSConnection(host=base_url)
    conn.request("GET", endpoint, headers=headers)
    response = conn.getresponse()
    conn.close()

    data = response.read()
    print(f"Response data: {data.decode('utf-8')}")

    return response.status, data.decode('utf-8')


def get_fastq_list(run_id: str, token: str):
    # request headers
    headers = {
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    # Retrieve the FASTQ list file from GDS
    gds_fastqs: str = f"/v1/files?volume.name={GDS_FASTQ_VOLUME}&path=/{run_id}/FASTQ-list.csv"
    status, body = req_to_endpoint(base_url=IAP_BASE_URL, endpoint=gds_fastqs, headers=headers)

    if status == 200:
        # Extract file ID from returned JSON
        iap_file_list_json = json.dumps(body)
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
        iap_file_detail_json = json.dumps(body)
        file_url = iap_file_detail_json['presignedUrl']
    else:
        raise(ValueError(f"Could not retrieve file records. Status {status}"))

    print(f"Presigned file url: {file_url}")


def lambda_handler(event, context):
    token = getSSMParam(SSM_PARAM_NAME)

    # XXX: Read from the API, **per run** FASTQ list from GDS
    run_id = event['run_id']
    fastqs = get_fastq_list(run_id, token)
    # XXX: Group the FASTQs from that FASTQ list, **per sample**
    # for fastq in fastqs:
    #     print(fastq)
    # XXX: Kick off the next task, **per sample**, i.e Dragen alignment

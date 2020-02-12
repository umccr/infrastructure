import os
import json
import boto3
import http.client

# SFN task to read FASTQ list for a given sequencing run and map individual FASTQs to SampleIDs.
# Splitting a run centric FASTQ list into sample centric FASTQ pairs.

GDS_FASTQ_VOLUME = 'umccr-fastq-data-dev'
GDS_FASTQ_LIST_DIR = 'FastqLists'

IAP_BASE_URL = os.environ.get("IAP_API_BASE_URL")
SSM_PARAM_JWT = os.environ.get("SSM_PARAM_JWT")
SSM_CLIENT = boto3.client('ssm')


def getSSMParam(name):
    """
    Fetch the parameter with the given name from SSM Parameter Store.
    """
    return SSM_CLIENT.get_parameter(
                Name=name,
                WithDecryption=True
            )['Parameter']['Value']


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


def find_fastq_lists(run_id: str, token: str):
    # request headers
    headers = {
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json',
        'cache-control': 'no-cache'
    }

    # Retrieve the FASTQ list file from GDS
    gds_fastqs: str = f"/v1/files?volume.name={GDS_FASTQ_VOLUME}&path=/{run_id}/{GDS_FASTQ_LIST_DIR}/*"
    status, body = req_to_endpoint(base_url=IAP_BASE_URL, endpoint=gds_fastqs, headers=headers)

    if status == 200:
        # Extract file ID from returned JSON
        print(body)

        iap_file_list_json = json.loads(body)
        count = iap_file_list_json['itemCount']
        print(f"itemCount: {count}")

        file_names = list()
        if count > 0:
            print(f"Retrieved {count} fastq lists.")
            for item in iap_file_list_json['items']:
                file_names.append(item['name'])
        else:
            raise(ValueError("FASTQ file list not found?"))
    else:
        raise(ValueError(f"Could not retrieve file list from IAP. Status {status}"))

    print(f"Retrieved files: {file_names}")
    return file_names


def lambda_handler(event, context):
    # Log the received event in CloudWatch
    print(f"Received event: {json.dumps(event)}")

    # Get run ID from input
    run_id = event['runId']

    # Get API jwt_token
    jwt_token = getSSMParam(SSM_PARAM_JWT)
    print(f"Retrieved JWT token: {jwt_token[:10]}..{jwt_token[-10:]}")

    # Retrieve the URL of the FASTA list file for the run
    fastq_lists = find_fastq_lists(run_id, jwt_token)

    # Process file names to get sample/lib names
    # (Depends on file naming conventions!)
    sample_names = list()
    for file_name in fastq_lists:
        sample_names.append(os.path.splitext(file_name)[0])

    return sample_names

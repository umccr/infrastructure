import os
import io
import json
import boto3
import http.client
import pandas as pd


STAGING_BUCKET = os.environ.get('STAGING_BUCKET')
SLACK_HOST = os.environ.get("SLACK_HOST")
SLACK_CHANNEL = os.environ.get("SLACK_CHANNEL")
HEADERS = {
    'Content-Type': 'application/json',
}

s3_client = boto3.client('s3')
ssm_client = boto3.client('ssm')
SLACK_WEBHOOK_ENDPOINT = ssm_client.get_parameter(
    Name='/slack/webhook/endpoint',
    WithDecryption=True
    )['Parameter']['Value']


# TODO: use common Slack lambda or support better message format
def call_slack_webhook(topic, title, message):
    connection = http.client.HTTPSConnection(SLACK_HOST)

    post_data = {
        "channel": SLACK_CHANNEL,
        "username": "Notice from AWS",
        "text": "*" + topic + "*",
        "icon_emoji": ":aws_logo:",
        "attachments": [{
            "title": title,
            "text": message
        }]
    }

    connection.request("POST", SLACK_WEBHOOK_ENDPOINT, json.dumps(post_data), HEADERS)
    response = connection.getresponse()
    connection.close()

    return response.status


def get_manifest_df(prefix: str):
    obj = s3_client.get_object(Bucket=STAGING_BUCKET, Key=f"{prefix}/manifest.txt")
    df = pd.read_csv(io.BytesIO(obj['Body'].read()), sep='\t', encoding='utf8')
    return df


def get_listing(prefix: str):
    # get the S3 object listing for the prefix
    files = list()
    file_batch = s3_client.list_objects_v2(
        Bucket=STAGING_BUCKET,
        Prefix=prefix
    )
    if file_batch.get('Contents'):
        files.extend(extract_filenames(file_batch['Contents']))
    while file_batch['IsTruncated']:
        token = file_batch['NextContinuationToken']
        file_batch = s3_client.list_objects_v2(
            Bucket=STAGING_BUCKET,
            Prefix=prefix,
            ContinuationToken=token
        )
        files.extend(extract_filenames(file_batch['Contents']))

    return files


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    message = event['Records'][0]['Sns']['Message']
    print(f"Extracted message: {message}")
    message = json.loads(message)

    bucket_name = message["Records"][0]["s3"]["bucket"]["name"]  # TODO: should probably be more robust
    if bucket_name != STAGING_BUCKET:
        raise ValueError(f"Buckets don't match received {bucket_name}, expected {STAGING_BUCKET}")

    obj_key = message["Records"][0]["s3"]["object"]["key"]
    submission_prefix = os.path.dirname(obj_key)
    print(f"Submission with prefix: {submission_prefix}")

    messages = list()
    manifest_df = get_manifest_df(submission_prefix)
    message = f"Entries in manifest: {len(manifest_df)}"
    print(message)
    messages.append(message)

    s3_files = set(get_listing(submission_prefix))
    message = f"Entries on S3: {len(s3_files)}"
    print(message)
    messages.append(message)

    # TODO: compare contents and check manifest format/data

import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

STAGING_BUCKET = os.environ.get('STAGING_BUCKET')
s3 = boto3.client('s3')


def find_folder_lock_statement(policy: dict):
    for stmt in policy.get('Statement'):
        if stmt.get('Sid') == "FolderLock":
            return stmt


def handler(event, context):
    logger.info(f"Start processing S3 event:")
    logger.info(json.dumps(event))

    resource_arns = list()
    s3_records = event.get('Records')
    for s3_record in s3_records:
        if s3_record['s3']['bucket']['name'] != STAGING_BUCKET:
            # Only manipulating bucket policy of the staging bucket
            logger.warning(f"S3 record for unexpected bucket {s3_record['s3']['bucket']['name']}. Skipping.")
            continue
        s3key: str = s3_record['s3']['object']['key']
        obj_prefix = os.path.dirname(s3key)
        resource_arns.append(f"arn:aws:s3:::{STAGING_BUCKET}/{obj_prefix}/*")
    logger.info(f"Updating folder lock with {len(resource_arns)} resources: {resource_arns}")

    resp = s3.get_bucket_policy(Bucket=STAGING_BUCKET)
    logger.info("Received policy response:")
    logger.info(resp)
    bucket_policy = json.loads(resp['Policy'])
    logger.info("Existing bucket policy:")
    logger.info(json.dumps(bucket_policy))

    fl_statement = find_folder_lock_statement(bucket_policy)
    fl_resource = fl_statement.get('Resource')
    # the resource could either be a list of strings or a single resource string
    # TODO: improvements: make sure there are no duplicates and sort ARNs
    if isinstance(fl_resource, list):
        resource_arns.extend(fl_resource)
    else:
        resource_arns.append(fl_resource)
    fl_statement['Resource'] = resource_arns

    bucket_policy_json = json.dumps(bucket_policy)
    logger.info("New bucket policy:")
    logger.info(bucket_policy_json)

    response = s3.put_bucket_policy(Bucket=STAGING_BUCKET, Policy=bucket_policy_json)
    logger.info(f"BucketPolicy update response: {response}")

    return response

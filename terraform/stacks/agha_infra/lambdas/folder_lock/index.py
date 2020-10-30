import json
import boto3
import os


def lambda_handler(event, context):
    print(f"Received event: {event}")

    message = event['Records'][0]['Sns']['Message']
    print(f"Extracted message: {message}")
    message = json.loads(message)

    bucket_name = message["Records"][0]["s3"]["bucket"]["name"]
    obj_key = message["Records"][0]["s3"]["object"]["key"]
    obj_prefix = os.path.dirname(obj_key)
    print(f"Placing restriction on prefix: {obj_prefix}")

    s3 = boto3.client('s3')
    result = s3.get_bucket_policy(Bucket=bucket_name)
    bucket_policy = result['Policy']
    bucket_policy = json.loads(bucket_policy)
    print(f"Existing bucket policy: {bucket_policy}")

    bucket_policy_addition = {
        'Effect': 'Deny',
        'Principal': '*',
        'Action': [
            's3:PutObject',
            's3:DeleteObject'
        ],
        'Resource': f'arn:aws:s3:::{bucket_name}/{obj_prefix}/*'
    }

    bucket_policy['Statement'].append(bucket_policy_addition)
    bucket_policy = json.dumps(bucket_policy)
    print(f"New bucket policy: {bucket_policy}")

    s3.put_bucket_policy(Bucket=bucket_name, Policy=bucket_policy)

    return {
        'statusCode': 200,
        'body': json.dumps('success')
    }

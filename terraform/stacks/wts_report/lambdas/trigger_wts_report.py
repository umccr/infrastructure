import os
import boto3
import json


def lambda_handler(event, context):
    # TODO implement
    batch_client = boto3.client('batch')
    s3 = boto3.client('s3')

    data_bucket = event["Records"][0]["s3"]["bucket"]["name"]
    obj_key = event["Records"][0]["s3"]["object"]["key"]
    data_wts_date_dir = os.path.dirname(obj_key)+"/"
    data_wts = os.path.dirname(data_wts_date_dir)
    data_dir = os.path.dirname(os.path.dirname(data_wts))+"/"
    container_overrides = event['containerOverrides'] if event.get('containerOverrides') else {}
    job_queue = event['jobQueue'] if event.get('jobQueue') else os.environ.get('JOBQUEUE')
    job_name = data_bucket + "---" + data_wts_date_dir.replace('/', '_').replace('.', '_')
    job_definition = os.environ.get('JOBDEF')
    refdata_bucket = os.environ.get('REFDATA_BUCKET')

    # print(f"bucket:{data_bucket}, data_dir:{data_dir}, data_wts_dir:{data_wts_dir}")
    # construct WTS results path
    data_intermediate = data_wts_date_dir+"final/"
    response1 = s3.list_objects(Bucket=data_bucket, Prefix=data_intermediate, Delimiter='/')
    data_wts_dir = response1["CommonPrefixes"][1]['Prefix'].strip("\'")
    # remove trailing slash from path
    data_wts_dir = data_wts_dir.rstrip('/')

    # construct WGS results path
    response2 = s3.list_objects(Bucket=data_bucket, Prefix=data_dir, Delimiter='/')
    common_prefixes = response2["CommonPrefixes"]
    if len(common_prefixes) == 2:
        result_WGS = common_prefixes[0]['Prefix'].strip("\'")
        result_WGS_umccrise = s3.list_objects(Bucket=data_bucket, Prefix=result_WGS, Delimiter='/')
        common_prefixes2 = result_WGS_umccrise["CommonPrefixes"]
        if len(common_prefixes2) == 1:
            result_WGS_umccrise = common_prefixes2[0]['Prefix'].strip("\'")+"umccrised/"
            sample_id = result_WGS_umccrise.split("/")[1]
            result_WGS_umccrise_sample = s3.list_objects(Bucket=data_bucket, Prefix=result_WGS_umccrise, Delimiter='/')
            common_prefixes3 = result_WGS_umccrise_sample["CommonPrefixes"]
            for i in range(0, len(common_prefixes3)-1):
                val = common_prefixes3[i]["Prefix"].strip("\'")
                if val.split(("/"))[-2].startswith(sample_id):
                    data_wgs_dir = val
                    # remove trailing slash from path
                    data_wgs_dir = data_wgs_dir.rstrip('/')
        else:
            print("More than one datestamps exist. We expect one timestamp for each WGS/WTS run. Anyway for this " +
                  "case comparing datestamps using string comparison - which might break if the result folder " +
                  "naming format changes")
            for i in range(0, len(common_prefixes2)-1):
                if (common_prefixes2[i]["Prefix"].strip("\'") < common_prefixes2[i+1]["Prefix"].strip("\'")):
                    result_WGS_umccrise = common_prefixes2[i+1]["Prefix"].strip("\'")+"umccrised/"

            result_WGS_umccrise_sample = s3.list_objects(Bucket=data_bucket, Prefix=result_WGS_umccrise, Delimiter='/')
            common_prefixes3 = result_WGS_umccrise_sample["CommonPrefixes"]
            for i in range(0, len(common_prefixes3)-1):
                val = common_prefixes3[i]["Prefix"].strip("\'")
                if val.split(("/"))[-2].startswith(sample_id):
                    data_wgs_dir = val
                    # remove trailing slash from path
                    data_wgs_dir = data_wgs_dir.rstrip('/')

    container_overrides['environment'] = [
        {'name': 'S3_WTS_INPUT_DIR', 'value': data_wts_dir},
        {'name': 'S3_WGS_INPUT_DIR', 'value': data_wgs_dir},
        {'name': 'S3_DATA_BUCKET', 'value': data_bucket},
        {'name': 'S3_REFDATA_BUCKET', 'value': refdata_bucket}
    ]
    container_overrides['vcpus'] = 8
    container_overrides['memory'] = 32000

    print("jobName: " + job_name)
    print("containerOverrides: ")
    print(container_overrides)
    print("jobDefinition: ")
    print(job_definition)
    response = batch_client.submit_job(
        containerOverrides=container_overrides,
        jobDefinition=job_definition,
        jobName=job_name,
        jobQueue=job_queue
    )

    # Log response from AWS Batch
    print("Response: " + json.dumps(response, indent=2))
    # Return the jobId
    event['jobId'] = response['jobId']
    return event

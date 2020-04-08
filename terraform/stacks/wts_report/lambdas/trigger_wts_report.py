import os
import boto3


def lambda_handler(event, context):
    # Log the received event
    print(f"Received event: {event}")
    # get the Batch client ready
    batch_client = boto3.client('batch')

    # Retrieve parameters
    container_overrides = event['containerOverrides'] if event.get('containerOverrides') else {}
    parameters = event['parameters'] if event.get('parameters') else {}
    depends_on = event['dependsOn'] if event.get('dependsOn') else []
    job_queue = event['jobQueue'] if event.get('jobQueue') else os.environ.get('JOBQUEUE')
    job_definition = event['jobDefinition'] if event.get('jobDefinition') else os.environ.get('JOBDEF')
    container_mem = event['memory'] if event.get('memory') else os.environ.get('JOB_MEM')
    container_vcpus = event['vcpus'] if event.get('vcpus') else os.environ.get('JOB_VCPUS')
    data_bucket = event['dataBucket'] if event.get('dataBucket') else os.environ.get('DATA_BUCKET')
    result_bucket = event['resultBucket'] if event.get('resultBucket') else data_bucket
    refdata_bucket = event['refDataBucket'] if event.get('refDataBucket') else os.environ.get('REFDATA_BUCKET')
    ref_dataset = event['refDataset'] if event.get('refDataset') else os.environ.get('REF_DATASET')
    genome_build = event['genomeBuild'] if event.get('genomeBUild') else os.environ.get('GENOME_BUILD')

    data_wts_dir = event['dataDirWTS']
    data_wgs_dir = event['dataDirWGS'] if event.get('dataDirWGS') else ""
    job_name = data_bucket + "---" + data_wts_dir.replace('/', '_').replace('.', '_')
    job_name = os.environ.get('JOBNAME_PREFIX') + '_' + job_name

    try:
        s3 = boto3.client('s3')
        print(f"Checking if data in WTS input S3 path ({data_wts_dir}) exists in bucket {data_bucket}")
        response_wts = s3.list_objects(Bucket=data_bucket, MaxKeys=3, Prefix=data_wts_dir)
        print(f"S3 list response: {response_wts}")
        if not response_wts.get('Contents') or len(response_wts['Contents']) < 1:
            return {
                'statusCode': 400,
                'error': 'Bad parameter',
                'message': f"Provided S3 path ({data_wts_dir}) does not exist in bucket {data_bucket}!"
            }

        if event.get('dataDirWGS'):
            print(f"Checking if data in WGS input S3 path ({data_wgs_dir}) exists in bucket {data_bucket}")
            response_wgs = s3.list_objects(Bucket=data_bucket, MaxKeys=3, Prefix=data_wgs_dir)
            print(f"S3 list response: {response_wgs}")
            if not response_wgs.get('Contents') or len(response_wgs['Contents']) < 1:
                return {
                    'statusCode': 400,
                    'error': 'Bad parameter',
                    'message': f"Provided S3 path ({data_wgs_dir}) does not exist in bucket {data_bucket}!"
                }

    # create and submit a Batch job request
        container_overrides['environment'] = [
            {'name': 'S3_WTS_INPUT_DIR', 'value': data_wts_dir},
            {'name': 'S3_WGS_INPUT_DIR', 'value': data_wgs_dir},
            {'name': 'S3_DATA_BUCKET', 'value': data_bucket},
            {'name': 'S3_RESULT_BUCKET', 'value': result_bucket},
            {'name': 'S3_REFDATA_BUCKET', 'value': refdata_bucket},
            {'name': 'REF_DATASET', 'value': ref_dataset},
            {'name': 'GENOME_BUILD', 'value': genome_build}
        ]

        if container_mem:
            container_overrides['memory'] = int(container_mem)
        if container_vcpus:
            container_overrides['vcpus'] = int(container_vcpus)
            parameters['vcpus'] = container_vcpus

        print("jobName: " + job_name)
        print("containerOverrides: ")
        print(container_overrides)
        print("jobDefinition: ")
        print(job_definition)
        response = batch_client.submit_job(
            dependsOn=depends_on,
            containerOverrides=container_overrides,
            jobDefinition=job_definition,
            jobName=job_name,
            jobQueue=job_queue,
            parameters=parameters
        )

        # Log response from AWS Batch
        print(f"Response: {response}")
        # Return the jobId
        event['jobId'] = response['jobId']
        return event

    except Exception as e:
        print(e)

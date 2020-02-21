import os
import json
import boto3


JOB_DEF_NAME = 'umccrise'
IMAGE_NAME = 'umccr/umccrise'
batch_client = boto3.client('batch')
s3 = boto3.client('s3')

batch_job_container_props = {
    # 'image': 'umccr/umccrise:0.15.15',  # this will be set on-demand
    'vcpus': 2,
    'memory': 2048,
    'command': [
        '/opt/container/umccrise-wrapper.sh',
        'Ref::vcpus'
    ],
    'volumes': [
        {
            'host': {
                'sourcePath': '/mnt'
            },
            'name': 'work'
        },
        {
            'host': {
                'sourcePath': '/opt/container'
            },
            'name': 'container'
        }
    ],
    'mountPoints': [
        {
            'containerPath': '/work',
            'readOnly': False,
            'sourceVolume': 'work'
        },
        {
            'containerPath': '/opt/container',
            'readOnly': True,
            'sourceVolume': 'container'
        }
    ],
    'readonlyRootFilesystem': False,
    'privileged': True,
    'ulimits': []
}


def job_name_form_s3(bucket, path):
    # Construct a meaningful default job name from bucket and S3 prefix
    # taking care of special characters that would otherwise cause issues downstream
    return bucket + "---" + path.replace('/', '_').replace('.', '_')


def lambda_handler(event, context):
    # Log the received event
    print(f"Received event: {event}")
    # Get parameters for the SubmitJob call
    # http://docs.aws.amazon.com/batch/latest/APIReference/API_SubmitJob.html

    # overwrite parameters if defined in the event/request, else use defaults from the environment
    # containerOverrides, dependsOn, and parameters are optional
    container_overrides = event['containerOverrides'] if event.get('containerOverrides') else {}
    parameters = event['parameters'] if event.get('parameters') else {}
    depends_on = event['dependsOn'] if event.get('dependsOn') else []
    job_queue = event['jobQueue'] if event.get('jobQueue') else os.environ.get('JOBQUEUE')
    image_version = event['imageVersion']

    container_mem = event['memory'] if event.get('memory') else os.environ.get('UMCCRISE_MEM')
    container_vcpus = event['vcpus'] if event.get('vcpus') else os.environ.get('UMCCRISE_VCPUS')
    data_bucket = event['dataBucket'] if event.get('dataBucket') else os.environ.get('DATA_BUCKET')
    result_bucket = event['resultBucket'] if event.get('resultBucket') else data_bucket
    refdata_bucket = event['refDataBucket'] if event.get('refDataBucket') else os.environ.get('REFDATA_BUCKET')
    result_dir = event['resultDir']
    job_name = event['jobName'] if event.get('jobName') else job_name_form_s3(data_bucket, result_dir)
    job_name = os.environ.get('JOBNAME_PREFIX') + '_' + job_name
    print(f"resultDir: {result_dir}  in data bucket: {data_bucket}")

    try:
        response = s3.list_objects(Bucket=data_bucket, MaxKeys=3, Prefix=result_dir)
        # print("S3 list response: " + json.dumps(response, indent=2, sort_keys=True, default=str))
        if not response.get('Contents') or len(response['Contents']) < 1:
            return {
                'statusCode': 400,
                'error': 'Bad parameter',
                'message': f"Provided S3 path ({result_dir}) does not exist in bucket {data_bucket}!"
            }

        # Inject S3 object from the data_bucket into parameters for AWS Batch and
        # inside the docker container
        # container_overrides = {'environment': [{'name': 'S3_INPUT_DIR', 'value': key}]}
        container_overrides['environment'] = [
            {'name': 'S3_INPUT_DIR', 'value': result_dir},
            {'name': 'S3_DATA_BUCKET', 'value': data_bucket},
            {'name': 'S3_RESULT_BUCKET', 'value': result_bucket},
            {'name': 'S3_REFDATA_BUCKET', 'value': refdata_bucket},
            {'name': 'CONTAINER_VCPUS', 'value': container_vcpus},
            {'name': 'CONTAINER_MEM', 'value': container_mem}
        ]
        if container_mem:
            container_overrides['memory'] = int(container_mem)
        if container_vcpus:
            container_overrides['vcpus'] = int(container_vcpus)
            parameters['vcpus'] = container_vcpus

        print(f"jobName: {job_name}")
        print(f"jobQueue: {job_queue}")
        print(f"parameters: {parameters}")
        print(f"dependsOn: {depends_on}")
        print(f"containerOverrides: {container_overrides}")

        # Set the container image version as requested
        batch_job_container_props['image'] = f"{IMAGE_NAME}:{image_version}"
        # register a job definition with those parameters
        print("INFO: Registering job definition")
        reg_response = batch_client.register_job_definition(
            jobDefinitionName=JOB_DEF_NAME,
            type='container',
            parameters=parameters,
            containerProperties=batch_job_container_props,
        )
        job_def_name = reg_response['jobDefinitionName']  # TODO: should be the same as JOB_DEF_NAME
        job_def_revision = reg_response['revision']
        job_definition = f"{job_def_name}:{job_def_revision}"

        print(f"Using jobDefinition: {job_definition}")
        response = batch_client.submit_job(
            dependsOn=depends_on,
            containerOverrides=container_overrides,
            jobDefinition=job_definition,
            jobName=job_name,
            jobQueue=job_queue,
            parameters=parameters  # probably not needed, as we're not overwriting anything
        )

        # Log response from AWS Batch
        print(f"Batch submit job response: {response}")
        # Return the jobId
        event['jobId'] = response['jobId']
        return event
    except Exception as e:
        print(e)

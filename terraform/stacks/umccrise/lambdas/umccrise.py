import os
import boto3


JOB_DEF_NAME = 'umccrise'
DH_IMAGE_NAME = 'umccr/umccrise'
ECR_IMAGE_NAME = '843407916570.dkr.ecr.ap-southeast-2.amazonaws.com/umccrise'
batch_client = boto3.client('batch')
s3 = boto3.client('s3')
IMAGE_CONFIGURABLE = os.environ.get('IMAGE_CONFIGURABLE') in ['true', 'True', 'TRUE']
JOB_DEF = os.environ.get('JOBDEF')

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


def job_name_from_s3(bucket, path):
    # Construct a meaningful default job name from bucket and S3 prefix
    # taking care of special characters that would otherwise cause issues downstream
    return bucket + "---" + path.replace('/', '_').replace('.', '_')


def lambda_handler(event, context):
    # Log the received event
    print(f"Received event: {event}")

    # Mandatory parameters
    input_dir = event['inputDir']

    # Get image version if configurable
    if IMAGE_CONFIGURABLE:
        print(f"Container image is configurable! Creating custom job definition.")
        container_image_version = event['imageVersion']  # mandatory parameter when image is configurable (in dev)
        container_image = DH_IMAGE_NAME if event.get('containerRepo') == 'DH' else ECR_IMAGE_NAME
        print(f"Using container image {container_image}")
        # Set the container image version as requested
        batch_job_container_props['image'] = f"{container_image}:{container_image_version}"
        # Register a job definition with those parameters
        print("INFO: Registering job definition")
        reg_response = batch_client.register_job_definition(
            jobDefinitionName=JOB_DEF_NAME,
            type='container',
            parameters={},  # Start with empty parameters, they may get overwritten on job launch time
            containerProperties=batch_job_container_props,
        )
        job_def_name = reg_response['jobDefinitionName']  # TODO: should be the same as JOB_DEF_NAME
        job_def_revision = reg_response['revision']
        job_definition = f"{job_def_name}:{job_def_revision}"
    else:
        print(f"Container image is not configurable! Using default job definition.")
        job_definition = JOB_DEF

    print(f"Using jobDefinition: {job_definition}")

    # Optional parameters
    container_overrides = event['containerOverrides'] if event.get('containerOverrides') else {}
    parameters = event['parameters'] if event.get('parameters') else {}
    depends_on = event['dependsOn'] if event.get('dependsOn') else []
    job_queue = event['jobQueue'] if event.get('jobQueue') else os.environ.get('JOBQUEUE')

    container_mem = event['memory'] if event.get('memory') else os.environ.get('UMCCRISE_MEM')
    container_vcpus = event['vcpus'] if event.get('vcpus') else os.environ.get('UMCCRISE_VCPUS')
    input_bucket = event['inputBucket'] if event.get('inputBucket') else os.environ.get('INPUT_BUCKET')
    result_bucket = event['resultBucket'] if event.get('resultBucket') else input_bucket
    refdata_bucket = event['refDataBucket'] if event.get('refDataBucket') else os.environ.get('REFDATA_BUCKET')
    job_name = event['jobName'] if event.get('jobName') else job_name_from_s3(input_bucket, input_dir)
    job_name = os.environ.get('JOBNAME_PREFIX') + '_' + job_name
    print(f"inputDir: {input_dir}  in input bucket: {input_bucket}")

    try:
        # Check if there are objects for the given input
        response = s3.list_objects(Bucket=input_bucket, MaxKeys=3, Prefix=input_dir)
        if not response.get('Contents') or len(response['Contents']) < 1:
            print(f"List request returned no result for path {input_dir} in bucket {input_bucket}")
            return {
                'statusCode': 400,
                'error': 'Bad parameter',
                'message': f"Provided S3 path ({input_dir}) does not exist in bucket {input_bucket}!"
            }

        # Set/Overwrite the environment of the container with our data
        container_overrides['environment'] = [
            {'name': 'S3_INPUT_DIR', 'value': input_dir},
            {'name': 'S3_DATA_BUCKET', 'value': input_bucket},
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

        # Preparae job submission
        # http://docs.aws.amazon.com/batch/latest/APIReference/API_SubmitJob.html
        print(f"jobName: {job_name}")
        print(f"jobQueue: {job_queue}")
        print(f"parameters: {parameters}")
        print(f"dependsOn: {depends_on}")
        print(f"containerOverrides: {container_overrides}")

        # Submit job
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

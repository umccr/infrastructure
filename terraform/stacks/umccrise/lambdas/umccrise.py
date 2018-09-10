import os
import json
import boto3

batch_client = boto3.client('batch')
s3 = boto3.client('s3')

# TODO: make the job name an input parameter
# TODO: make more generic
#       i.e. parse/expect different input parameters depending on job definition/type


def lambda_handler(event, context):
    # Log the received event
    print("Received event: " + json.dumps(event, indent=2))
    # Get parameters for the SubmitJob call
    # http://docs.aws.amazon.com/batch/latest/APIReference/API_SubmitJob.html

    # overwrite parameters if defined in the event/request, else use defaults from the environment
    # containerOverrides, dependsOn, and parameters are optional
    container_overrides = event['containerOverrides'] if event.get('containerOverrides') else {}
    parameters = event['parameters'] if event.get('parameters') else {}
    depends_on = event['dependsOn'] if event.get('dependsOn') else []
    job_name = event['jobName'] if event.get('jobName') else os.environ.get('JOBNAME')
    job_queue = event['jobQueue'] if event.get('jobQueue') else os.environ.get('JOBQUEUE')
    job_definition = event['jobDefinition'] if event.get('jobDefinition') else os.environ.get('JOBDEF')

    container_mem = event['memory'] if event.get('memory') else ""
    container_vcpus = event['vcpus'] if event.get('vcpus') else ""
    bucket = event['bucket'] if event.get('bucket') else os.environ.get('BUCKET')
    result_dir = event['resultDir']
    print("resultDir: %s  in bucket: %s" % (result_dir, bucket))

    try:
        response = s3.list_objects(Bucket=bucket, MaxKeys=5, Prefix=result_dir)
        print("Response: " + json.dumps(response, indent=2, sort_keys=True, default=str))

        # Inject S3 object from the bucket into parameters for AWS Batch and
        # inside the docker container
        # container_overrides = {'environment': [{'name': 'S3_INPUT_DIR', 'value': key}]}
        container_overrides['environment'] = [{'name': 'S3_INPUT_DIR', 'value': result_dir}]
        if container_mem:
            container_overrides['memory'] = int(container_mem)
        if container_vcpus:
            container_overrides['vcpus'] = int(container_vcpus)
            parameters['vcpus'] = container_vcpus

        print("jobName: " + job_name)
        print("jobQueue: " + job_queue)
        print("parameters: ")
        print(parameters)
        print("dependsOn: ")
        print(depends_on)
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
        print("Response: " + json.dumps(response, indent=2))
        # Return the jobId
        event['jobId'] = response['jobId']
        return event
    except Exception as e:
        print(e)

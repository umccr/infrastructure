#!/usr/bin/env python

import os
import boto3
import base64
import json
from pathlib import Path

IMAGE_NAME = "quay.io/umccr/cttso-ica-to-pieriandx:1.0.0"
SSM_ENV_VAR_PATH = Path("/cdk/cttso-ica-to-pieriandx/env_vars/")

# Get job parameters
JOB_DEF = os.environ.get('JOBDEF')
JOB_QUEUE = os.environ.get('JOBQUEUE')
JOBNAME_PREFIX = os.environ.get('JOBNAME_PREFIX')
MEM = os.environ.get('MEM')
VCPUS = os.environ.get('VCPUS')

# Get batch client
batch_client = boto3.client('batch')
ssm_client = boto3.client('ssm')

# job container properties for dynamic JobDefinition
batch_job_container_props = {
    'image': None,
    'vcpus': 1,
    'memory': 1000,
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
    'ulimits': []
}


def lambda_handler(event, context):
    # Log the received event
    print(f"Received event: {event}")

    print(f"Using jobDefinition: {JOB_DEF}")

    # Check mandatory parameters
    parameters = event['parameters'] if event.get('parameters') else {}

    if parameters.get("ica_workflow_run_id", None) is None:
        print("Error: please specify 'ica_workflow_run_id' in parameters")
        raise ValueError
    if parameters.get("accession_json_base64_str", None) is None:
        print("Error: please specify 'accession_json_base64_str' in parameters")
        raise ValueError

    # Get optional parameters
    container_overrides = event['containerOverrides'] if event.get('containerOverrides') else {}
    depends_on = event['dependsOn'] if event.get('dependsOn') else []
    job_queue = event['jobQueue'] if event.get('jobQueue') else JOB_QUEUE

    # Override memory and vcpus if necessary
    container_mem = event['memory'] if event.get('memory') else MEM
    container_vcpus = event['vcpus'] if event.get('vcpus') else VCPUS
    if container_mem:
        container_overrides['memory'] = int(container_mem)
    if container_vcpus:
        container_overrides['vcpus'] = int(container_vcpus)
        parameters['vcpus'] = container_vcpus

    # Get accession name to get job id
    accession_json = json.loads(base64.b64decode(parameters.get("accession_json_base64_str")).decode("ascii"))
    accession_number = accession_json.get("accession_number")
    job_name = JOBNAME_PREFIX + '_' + parameters.get("ica_workflow_run_id") + accession_number

    # Set existing environment if it doesnt exist yet.
    container_overrides['environment'] = container_overrides.get("environment", {})

    # Check all ssm parameters are available
    default_environment_var_list = [
        "ICA_BASE_URL",
        "PIERIANDX_BASE_URL",
        "PIERIANDX_INSTITUTION",
        #"ICA_ACCESS_TOKEN",
        "PIERIANDX_AWS_REGION",
        "PIERIANDX_AWS_S3_PREFIX",
        #"PIERIANDX_AWS_ACCESS_KEY_ID",
        #"PIERIANDX_AWS_SECRET_ACCESS_KEY",
        "PIERIANDX_USER_EMAIL",
        #"PIERIANDX_USER_PASSWORD"
    ]

    for env_var in default_environment_var_list:
        # Check if its in the overrides first, if so we skip it
        if env_var in container_overrides['environment'].keys():
            continue

        # Otherwise get the value from SSM
        ssm_parameter_obj = ssm_client.get_parameter(Name=str(SSM_ENV_VAR_PATH / env_var),
                                                     WithDecrption=True)

        # Check we got the parameter
        if ssm_parameter_obj is None or ssm_parameter_obj.get("Parameter") is None:
            print(f"Could not get parameter {str(SSM_ENV_VAR_PATH / env_var)}")
            exit()

        # Get the parameter dict
        parameter_dict = ssm_parameter_obj.get("Parameter")

        # Make sure value is valid
        if parameter_dict.get("Value", None) is None or len(parameter_dict.get("Value")) == 0:
            print(f"Could not get parameter {str(SSM_ENV_VAR_PATH / env_var)}")
            exit()

        # Assign the parameter value to the overrides
        container_overrides['environment'][env_var] = parameter_dict.get("Value")

    try:
        # Prepare job submission
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
            jobDefinition=JOB_DEF,
            jobName=job_name,
            jobQueue=job_queue,
            parameters=parameters,  # probably not needed, as we're not overwriting anything
        )

        # Log response from AWS Batch
        print(f"Batch submit job response: {response}")

        # Return the jobId
        event['jobId'] = response['jobId']

        return event

    except Exception as e:
        print(e)

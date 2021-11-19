#!/usr/bin/env python3
import os
import aws_cdk as cdk
import boto3
from stacks.cttso_ica_to_pieriandx import CttsoIcaToPieriandxStack
from stacks.cttso_docker_codebuild import CttsoIcaToPieriandxDockerBuildStack

# Get ssm client
ssm_client = boto3.client('ssm')

# Get ssm parameters
ec2_ami = ssm_client.get_parameter(Name='/cdk/cttso-ica-to-pieriandx/batch/ami')['Parameter']['Value']
# rw_bucket = ssm_client.get_parameter(Name='/cdk/cttso-ica-to-pieriandx/batch/rw_buckets')['Parameter']['Value']
image_name = ssm_client.get_parameter(Name='/cdk/cttso-ica-to-pieriandx/batch/docker-image-tag')['Parameter']['Value']

# Call app
app = cdk.App()

# Use CDK_DEFAULT_ACCOUNT and CDK_DEFAULT_REGION
account_id = os.environ.get('CDK_DEFAULT_ACCOUNT')
aws_region = os.environ.get('CDK_DEFAULT_REGION')
aws_env = {"account": account_id, "region": aws_region}

# Set properties for cdk
# Get codebuild properties
codebuild_props = {
    'namespace': "CttsoIcaToPieriandxDockerBuildStack",
    'container_repo': f'{account_id}.dkr.ecr.{aws_region}.amazonaws.com',
    'codebuild_project_name': 'cttso-ica-to-pieriandx-codebuild',
    'container_name': "cttso-ica-to-pieriandx",
    'region': aws_region,
    'image_name': image_name
}

batch_props = {
    'namespace': "CttsoIcaToPieriandxStack",
    'compute_env_ami': ec2_ami,  # Should be Amazon ECS optimised Linux 2 AMI
    "image_name": image_name
    # 'rw_bucket': rw_bucket,  # For writing out wrapper script
}

# Get docker build stack
CttsoIcaToPieriandxDockerBuildStack(app, codebuild_props.get("namespace"),
                                    stack_name=codebuild_props.get("namespace").lower(),
                                    props=codebuild_props,
                                    env=aws_env)

# Get ica to pieriandx stack
CttsoIcaToPieriandxStack(app, batch_props.get("namespace"),
                         stack_name=batch_props.get("namespace").lower(),
                         props=batch_props,
                         env=aws_env)

# Get synth
app.synth()

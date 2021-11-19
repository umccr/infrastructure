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
rw_bucket = ssm_client.get_parameter(Name='/cdk/cttso-ica-to-pieriandx/batch/rw_buckets')['Parameter']['Value']
ssm_tag_parameter_path = '/cdk/cttso-ica-to-pieriandx/batch/docker-image-tag'

# Call app
app = cdk.App()

# Use CDK_DEFAULT_ACCOUNT and CDK_DEFAULT_REGION
account_id = os.environ.get('CDK_DEFAULT_ACCOUNT')
aws_region = os.environ.get('CDK_DEFAULT_REGION')
aws_env = cdk.Environment(account=account_id, region=aws_region)

# Set properties for cdk
# Get codebuild properties
codebuild_props = {
    'container_repo': f'{account_id}.dkr.ecr.{aws_region}.amazonaws.com',
    'container_name': "cttso-ica-to-pieriandx",
    'region': aws_region,
    'ssm_tag_parameter_path': ssm_tag_parameter_path
}

batch_props = {
    'namespace': "CttsoIcaToPieriandxStack",
    'compute_env_ami': ec2_ami,  # Should be Amazon ECS optimised Linux 2 AMI
    'rw_bucket': rw_bucket,  # For writing out wrapper script
}


# Get docker build stack
CttsoIcaToPieriandxDockerBuildStack(app, batch_props.get("namespace"), props=codebuild_props, env=aws_env)

# Extend properties by getting container image value (now that the build stack has been added)
batch_props['image_name'] = ssm_client.get_parameter(Name=ssm_tag_parameter_path)['Parameter']['Value']

# Get ica to pieriandx stack
CttsoIcaToPieriandxStack(app, batch_props.get("namespace"), props=batch_props, env=aws_env)

# Get synth
app.synth()

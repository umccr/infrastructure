#!/usr/bin/env python3
import os
import aws_cdk as cdk
import boto3
from cttso_ica_to_pieriandx.cttso_ica_to_pieriandx_stack import CttsoIcaToPieriandxStack

# Get ssm client
ssm_client = boto3.client('ssm')

# Get ssm parameters
ec2_ami = ssm_client.get_parameter(Name='/cdk/cttso-ica-to-pieriandx/batch/ami')['Parameter']['Value']
rw_bucket = ssm_client.get_parameter(Name='/cdk/cttso-ica-to-pieriandx/batch/rw_buckets')['Parameter']['Value']

# Call app
app = cdk.App()

# Use CDK_DEFAULT_ACCOUNT and CDK_DEFAULT_REGION
account_id = os.environ.get('CDK_DEFAULT_ACCOUNT')
aws_region = os.environ.get('CDK_DEFAULT_REGION')
aws_env = cdk.Environment(account=account_id, region=aws_region)

# Set properties for cdk
batch_props = {
    'namespace': "CttsoIcaToPieriandxStack",
    'compute_env_ami': ec2_ami,  # Should be Amazon ECS optimised Linux 2 AMI
    'rw_bucket': rw_bucket,  # For writing out wrapper script
}

# Get ica to pieriandx stack
CttsoIcaToPieriandxStack(app, batch_props.get("namespace"), props=batch_props, env=aws_env)

# Get synth
app.synth()

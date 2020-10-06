#!/usr/bin/env python3

import os
from aws_cdk import core
import boto3

from stacks.agha_stack import AghaStack

ssm_client = boto3.client('ssm')

slack_host = ssm_client.get_parameter(Name='/slack/webhook/host')['Parameter']['Value']
slack_channel = ssm_client.get_parameter(Name='/slack/channel')['Parameter']['Value']

# retrieve AWS details from currently active AWS profile/credentials
aws_env = {
    'account': os.environ.get('CDK_DEFAULT_ACCOUNT'),
    'region': os.environ.get('CDK_DEFAULT_REGION')
}

agha_props = {
    'namespace': 'agha',
    'staging_bucket': 'agha-gdr-staging',
    'slack_host': slack_host,
    'slack_channel': slack_channel,
    'manager_email': 'sarah.casauria@mcri.edu.au',
    'sender_email': 'services@umccr.org'
}


app = core.App()

AghaStack(
    app,
    agha_props['namespace'],
    agha_props,
    env=aws_env
)

app.synth()

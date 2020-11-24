#!/usr/bin/env python3
import os

from aws_cdk import core
from stacks.goserver import GoServerStack

account_id = os.environ.get('CDK_DEFAULT_ACCOUNT')
aws_region = os.environ.get('CDK_DEFAULT_REGION')
aws_env = {'account': account_id, 'region': aws_region}

htsget_props = {
    'namespace': 'htsget-refserver'
}

app = core.App()

GoServerStack(
    app,
    htsget_props['namespace'],
    props=htsget_props,
    env=aws_env
)

app.synth()

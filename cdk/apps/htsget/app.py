#!/usr/bin/env python3
import os

from aws_cdk import core
import aws_cdk.aws_ssm as ssm
from htsget.common import CommonStack
from htsget.goserver import GoServerStack

account_id = os.environ.get('CDK_DEFAULT_ACCOUNT')
aws_region = os.environ.get('CDK_DEFAULT_REGION')
aws_env = {'account': account_id, 'region': aws_region}

htsget_props = {
    'namespace': "htsget-refserver",
    'htsget_refserver_image_tag': "1.4.1_2",
    'cors_allowed_origins': ["https://data.umccr.org", "https://data.dev.umccr.org", "http://localhost:3000"],
}

app = core.App()

common = CommonStack(
    app,
    "htsget-common",
    props=htsget_props,
    env=aws_env
)
htsget_props['ecr_repo'] = common.ecr_repo

GoServerStack(
    app,
    htsget_props['namespace'],
    props=htsget_props,
    env=aws_env
)

tags = {
    'Stack': htsget_props['namespace'],
    'Creator': "cdk",
    'Environment': account_id,
}

for k, v in tags.items():
    core.Tags.of(app).add(key=k, value=v)

app.synth()

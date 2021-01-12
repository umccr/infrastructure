#!/usr/bin/env python3
import os

from aws_cdk import core
from htsget.common import CommonStack
from htsget.goserver import GoServerStack

account_id = os.environ.get('CDK_DEFAULT_ACCOUNT')
aws_region = os.environ.get('CDK_DEFAULT_REGION')
aws_env = {'account': account_id, 'region': aws_region}

htsget_props = {
    'namespace': "htsget-refserver",
    'htsget_refserver_image_tag': "1.4.1_1",
    'cors_allowed_origins':  ["https://data.umccr.org", "https://data.dev.umccr.org"],
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

app.synth()

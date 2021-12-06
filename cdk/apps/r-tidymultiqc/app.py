#!/usr/bin/env python3
import os

from aws_cdk import core as cdk
from aws_cdk import core

from aws_lambda_container_cdk_r.aws_lambda_container_cdk_r_stack import AwsLambdaContainerCdkRStack

account_id = os.environ.get('CDK_DEFAULT_ACCOUNT')
aws_region = os.environ.get('CDK_DEFAULT_REGION')
aws_env = {'account': account_id, 'region': aws_region}

app = core.App()
AwsLambdaContainerCdkRStack(app, "AwsLambdaContainerCdkRStack",
    env=core.Environment(account=account_id, region=aws_region),
)

app.synth()

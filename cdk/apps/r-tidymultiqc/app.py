#!/usr/bin/env python3
import os

from aws_cdk import core as cdk
from aws_cdk import core

from aws_lambda_container_cdk_r.aws_lambda_container_cdk_r_stack import AwsLambdaContainerCdkRStack


app = core.App()
AwsLambdaContainerCdkRStack(app, "AwsLambdaContainerCdkRStack",
    env=core.Environment(account=os.getenv('CDK_DEFAULT_ACCOUNT'), region=os.getenv('CDK_DEFAULT_REGION')),
)

app.synth()

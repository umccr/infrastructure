#!/usr/bin/env python3

from aws_cdk import core
from stacks.slack_lambda import IapLambdaStack, BatchLambdaStack


app = core.App()
IapLambdaStack(app, "iap-slack-lambda", env={'region': 'ap-southeast-2'})
BatchLambdaStack(app, "batch-slack-lambda", env={'region': 'ap-southeast-2'})

app.synth()

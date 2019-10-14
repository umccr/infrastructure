#!/usr/bin/env python3

from aws_cdk import core
from stacks.slack_lambda import IapLambdaStack, BatchLambdaStack


app = core.App()
IapLambdaStack(app, "iap-slack-lambda-dev", env={'account': '843407916570', 'region': 'ap-southeast-2'})
IapLambdaStack(app, "iap-slack-lambda-prod", env={'account': '472057503814', 'region': 'ap-southeast-2'})
BatchLambdaStack(app, "batch-slack-lambda-dev", env={'account': '843407916570', 'region': 'ap-southeast-2'})
BatchLambdaStack(app, "batch-slack-lambda-prod", env={'account': '472057503814', 'region': 'ap-southeast-2'})

app.synth()

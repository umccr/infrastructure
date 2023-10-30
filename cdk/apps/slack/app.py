#!/usr/bin/env python3

from aws_cdk import App
from stacks.slack_lambda import IapLambdaStack, BatchLambdaStack


app = App()

# TODO DEPRECATED STACK
# IapLambdaStack(
#     app,
#     "iap-slack-lambda-dev",
#     env={'account': '843407916570', 'region': 'ap-southeast-2'},
#     slack_channel='#arteria-dev'
# )
# IapLambdaStack(
#     app,
#     "iap-slack-lambda-prod",
#     env={'account': '472057503814', 'region': 'ap-southeast-2'},
#     slack_channel='#biobots'
# )
BatchLambdaStack(
    app,
    "batch-slack-lambda-dev",
    env={'account': '843407916570', 'region': 'ap-southeast-2'},
    slack_channel='#arteria-dev'
)
# TODO DEPRECATED STACK
# BatchLambdaStack(
#     app,
#     "batch-slack-lambda-dev-old",
#     env={'account': '620123204273', 'region': 'ap-southeast-2'},
#     slack_channel='#arteria-dev'
# )
BatchLambdaStack(
    app,
    "batch-slack-lambda-prod",
    env={'account': '472057503814', 'region': 'ap-southeast-2'},
    slack_channel='#biobots'
)
BatchLambdaStack(
    app,
    "batch-slack-lambda-stg",
    env={'account': '455634345446', 'region': 'ap-southeast-2'},
    slack_channel='#devops-alerts'
)

app.synth()

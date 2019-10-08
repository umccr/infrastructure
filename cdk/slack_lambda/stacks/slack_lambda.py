from aws_cdk import (
    aws_lambda as _lambda,
    core
)


class IapLambdaStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        function = _lambda.Function(self,
                                    'IapSlackLambda',
                                    handler='iap_notify_slack.lambda_handler',
                                    runtime=_lambda.Runtime.PYTHON_3_7,
                                    code=_lambda.Code.asset('lambda'),
                                    environment={"SLACK_HOST": "hooks.slack.com",
                                                 "SLACK_CHANNEL": "#arteria-dev"},
                                    )


class BatchLambdaStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        function = _lambda.Function(self,
                                    'BatchSlackLambda',
                                    handler='batch_notify_slack.lambda_handler',
                                    runtime=_lambda.Runtime.PYTHON_3_7,
                                    code=_lambda.Code.asset('lambda'),
                                    environment={"SLACK_HOST": "hooks.slack.com",
                                                 "SLACK_CHANNEL": "#arteria-dev"},
                                    )

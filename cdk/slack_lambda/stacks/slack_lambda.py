from aws_cdk import (
    aws_lambda as _lambda,
    aws_iam as _iam,
    core
)


class IapLambdaStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        lambda_role = _iam.Role(self,
                                'SlackLambdaRole',
                                assumed_by=_iam.ServicePrincipal('lambda.amazonaws.com'),
                                managed_policies=[_iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMReadOnlyAccess'),
                                                  _iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')]
                                )

        function = _lambda.Function(self,
                                    'IapSlackLambda',
                                    handler='iap_notify_slack.lambda_handler',
                                    runtime=_lambda.Runtime.PYTHON_3_7,
                                    code=_lambda.Code.asset('lambda'),
                                    environment={"SLACK_HOST": "hooks.slack.com",
                                                 "SLACK_CHANNEL": "#arteria-dev"},
                                    role=lambda_role
                                    )


class BatchLambdaStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        lambda_role = _iam.Role(self,
                                'SlackLambdaRole',
                                assumed_by=_iam.ServicePrincipal('lambda.amazonaws.com'),
                                managed_policies=[_iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMReadOnlyAccess'),
                                                  _iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')]
                                )
        function = _lambda.Function(self,
                                    'BatchSlackLambda',
                                    handler='batch_notify_slack.lambda_handler',
                                    runtime=_lambda.Runtime.PYTHON_3_7,
                                    code=_lambda.Code.asset('lambda'),
                                    environment={"SLACK_HOST": "hooks.slack.com",
                                                 "SLACK_CHANNEL": "#arteria-dev"},
                                    role=lambda_role
                                    )

from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    core
)


class AghaStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, props: dict, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        lambda_role = iam.Role(
            self,
            'ValidationLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole'),
                iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMReadOnlyAccess'),  # TODO: restrict!
                iam.ManagedPolicy.from_aws_managed_policy_name('AmazonS3ReadOnlyAccess')  # TODO: restrict!
            ]
        )
        lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "ses:SendEmail",
                    "ses:SendRawEmail"
                ],
                resources=["*"]
            )
        )


        pandas_layer = lmbda.LayerVersion(
            self,
            "PandasLambdaLayer",
            code=lmbda.Code.from_asset("lambdas/layers/pandas/python37-pandas.zip"),
            compatible_runtimes=[lmbda.Runtime.PYTHON_3_7],
            description="A pandas layer for python 3.7"
        )

        scipy_layer = lmbda.LayerVersion.from_layer_version_arn(
            self,
            id="SciPyLambdaLayer",
            layer_version_arn='arn:aws:lambda:ap-southeast-2:817496625479:layer:AWSLambda-Python37-SciPy1x:20'
        )

        lmbda.Function(
            self,
            'ValidationLambda',
            function_name=f"{props['namespace']}_validation_lambda",
            handler='validation.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas/validation'),
            environment={
                'STAGING_BUCKET': props['staging_bucket'],
                'SLACK_HOST': props['slack_host'],
                'SLACK_CHANNEL': props['slack_channel'],
                'MANAGER_EMAIL': props['manager_email'],
                'SENDER_EMAIL': props['sender_email']
            },
            role=lambda_role,
            layers=[
                pandas_layer,
                scipy_layer
            ]
        )

        lmbda.Function(
            self,
            'PlaygroundLambda',
            function_name=f"{props['namespace']}_playground_lambda",
            handler='playground.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas/playground'),
            environment={
                'STAGING_BUCKET': props['staging_bucket'],
                'SLACK_HOST': props['slack_host'],
                'SLACK_CHANNEL': props['slack_channel'],
                'MANAGER_EMAIL': props['manager_email'],
                'SENDER_EMAIL': props['sender_email']
            },
            role=lambda_role,
            layers=[
                pandas_layer,
                scipy_layer
            ]
        )

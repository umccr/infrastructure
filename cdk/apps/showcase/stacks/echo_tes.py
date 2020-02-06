from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    aws_ssm as ssm,
    core
)


class EchoTesStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        lambda_role = iam.Role(
            self,
            'EchoTesLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')
            ]
        )

        function = lmbda.Function(
            self,
            'EchoTesLambda',
            function_name='echo_iap_tes_lambda_dev',
            handler='echo_tes.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas/echo_tes'),
            role=lambda_role,
            timeout=core.Duration.seconds(20),
            environment={
                'IAP_API_BASE_URL': props['iap_api_base_url'],
                'TASK_ID': props['task_id'],
                'TASK_VERSION': props['task_version'],
                'SSM_PARAM_NAME': props['ssm_param_name'],
                'IMAGE_NAME': props['image_name'],
                'IMAGE_TAG': props['image_tag']
            }
        )

        secret_value = ssm.StringParameter.from_secure_string_parameter_attributes(
            self,
            "sJwtToken",
            parameter_name=props['ssm_param_name'],
            version=props['ssm_param_version']
        )
        secret_value.grant_read(function)

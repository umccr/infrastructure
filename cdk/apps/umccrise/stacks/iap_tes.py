from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    aws_ssm as ssm,
    core
)


class IapTesStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        lambda_role = iam.Role(
            self,
            'IapTesLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')
            ]
        )

        function = lmbda.Function(
            self,
            'IapTesLambda',
            function_name='umccrise_iap_tes_lambda_dev',
            handler='iap_tes.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas/iap_tes'),
            role=lambda_role,
            environment={
                'IAP_API_BASE_URL': props['iap_api_base_url'],
                'TASK_ID': props['task_id'],
                'TASK_VERSION_ID': props['task_version_id'],
                'SSM_PARAM_NAME': props['ssm_param_name'],
                'GDS_REFDATA_FOLDER': props['gds_refdata_folder'],
                'GDS_OUTPUT_FOLDER': props['gds_output_folder'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'UMCCRISE_IMAGE_NAME': props['umccrise_image_name'],
                'UMCCRISE_IMAGE_TAG': props['umccrise_image_tag']
            }
        )

        secret_value = ssm.StringParameter.from_secure_string_parameter_attributes(
            self,
            "MySecureValue",
            parameter_name=props['ssm_param_name'],
            version=props['ssm_param_version']
        )
        secret_value.grant_read(function)

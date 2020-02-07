from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    aws_ssm as ssm,
    aws_stepfunctions as sfn,
    aws_stepfunctions_tasks as sfn_tasks,
    core,
)

class OrchestratorStack(core.Stack):
    def __init__(self, app: core.App, id: str, props, **kwargs) -> None:
        super().__init__(app, id, **kwargs)

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
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': props['image_name'],
                'IMAGE_TAG': props['image_tag']
            }
        )

        secret_value = ssm.StringParameter.from_secure_string_parameter_attributes(
            self,
            "JwtToken",
            parameter_name=props['ssm_param_name'],
            version=props['ssm_param_version']
        )
        secret_value.grant_read(function)

        submit_lambda_task = sfn_tasks.RunLambdaTask(function, 
                                integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
                                payload={"taskCallbackToken": sfn.Context.task_token, "echoParameter": "FooBar"})

        # TASK definitions
        tes_task = sfn.Task(
            self, "Submit TES",
            task= submit_lambda_task,
            result_path="$.guid",
        )

        job_succeeded = sfn.Succeed(
            self, "Job Succeeded"
        )

        job_failed = sfn.Fail(
            self, "Job Failed",
            cause="AWS Batch Job Failed",
            error="DescribeJob returned FAILED"
        )

        wait_x = sfn.Wait(
            self, "Wait X Seconds",
            time=sfn.WaitTime.seconds_path('$.wait_time'),
        )

        is_complete = sfn.Choice(
            self, "Job Complete?"
        )

        definition = tes_task \
            .next(is_complete
                .when(sfn.Condition.string_equals(
                    "$.status", "FAILED"), job_failed) \
                .when(sfn.Condition.string_equals(
                    "$.status", "SUCCEEDED"), job_succeeded) \
                .otherwise(wait_x))

        sfn.StateMachine(
            self, "StateMachine",
            definition=definition,
        )
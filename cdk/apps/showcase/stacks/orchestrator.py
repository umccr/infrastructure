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

        callback_role = iam.Role(
            self,
            'CallbackTesLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole'),
                iam.ManagedPolicy.from_aws_managed_policy_name('AWSStepFunctionsFullAccess')
            ]
        )

        # Lambda function to call back and complete SFN async tasks
        callback_function = lmbda.Function(
            self,
            'CallbackLambda',
            function_name='callback_iap_tes_lambda_dev',
            handler='callback.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas'),
            role=callback_role,
            timeout=core.Duration.seconds(20)
        )

        samplesheet_mapper_function = lmbda.Function(
            self,
            'SampleSheetMapperTesLambda',
            function_name='showcase_ss_mapper_iap_tes_lambda_dev',
            handler='launch_tes_task.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas'),
            role=lambda_role,
            timeout=core.Duration.seconds(20),
            environment={
                'IAP_API_BASE_URL': props['iap_api_base_url'],
                'TASK_ID': props['task_id'],
                'TASK_VERSION': props['task_version'],
                'SSM_PARAM_JWT': props['ssm_param_name'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': props['image_name'],
                'IMAGE_TAG': props['image_tag'],
                'TES_TASK_NAME': 'SampleSheetMapper'
            }
        )

        bcl_convert_function = lmbda.Function(
            self,
            'BclConvertTesLambda',
            function_name='showcase_bcl_convert_iap_tes_lambda_dev',
            handler='launch_tes_task.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas'),
            role=lambda_role,
            timeout=core.Duration.seconds(20),
            environment={
                'IAP_API_BASE_URL': props['iap_api_base_url'],
                'TASK_ID': props['task_id'],
                'TASK_VERSION': props['task_version'],
                'SSM_PARAM_JWT': props['ssm_param_name'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': props['image_name'],
                'IMAGE_TAG': props['image_tag'],
                'TES_TASK_NAME': 'BclConvert'
            }
        )

        fastq_mapper_function = lmbda.Function(
            self,
            'FastqMapperTesLambda',
            function_name='showcase_fastq_mapper_iap_tes_lambda_dev',
            handler='launch_tes_task.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas'),
            role=lambda_role,
            timeout=core.Duration.seconds(20),
            environment={
                'IAP_API_BASE_URL': props['iap_api_base_url'],
                'TASK_ID': props['task_id'],
                'TASK_VERSION': props['task_version'],
                'SSM_PARAM_JWT': props['ssm_param_name'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': props['image_name'],
                'IMAGE_TAG': props['image_tag'],
                'TES_TASK_NAME': 'FastqMapper'
            }
        )

        # IAP JWT access token stored in SSM Parameter Store
        secret_value = ssm.StringParameter.from_secure_string_parameter_attributes(
            self,
            "JwtToken",
            parameter_name=props['ssm_param_name'],
            version=props['ssm_param_version']
        )
        secret_value.grant_read(samplesheet_mapper_function)
        secret_value.grant_read(fastq_mapper_function)
        secret_value.grant_read(bcl_convert_function)

        # SFN task definitions
        submit_lambda_task = sfn_tasks.RunLambdaTask(
            samplesheet_mapper_function,
            integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
            payload={"taskCallbackToken": sfn.Context.task_token, "runId.$": "$.runfolder"})

        second_lambda_task = sfn_tasks.RunLambdaTask(
            fastq_mapper_function,
            integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
            payload={"taskCallbackToken": sfn.Context.task_token, "runId.$": "$.runfolder"})

        bcl_convert_lambda_task = sfn_tasks.RunLambdaTask(
            bcl_convert_function,
            integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
            payload={"taskCallbackToken": sfn.Context.task_token, "runId.$": "$.runfolder"})

        tes_task = sfn.Task(
            self, "Submit TES",
            task=submit_lambda_task,
            result_path="$.guid",
        )

        tes_task2 = sfn.Task(
            self, "Submit TES task 2",
            task=second_lambda_task,
            result_path="$.guid",
        )

        tes_task3 = sfn.Task(
            self, "Submit TES task 3",
            task=bcl_convert_lambda_task,
            result_path="$.guid",
        )

        # job_succeeded = sfn.Succeed(
        #     self, "Job Succeeded"
        # )

        # job_failed = sfn.Fail(
        #     self, "Job Failed",
        #     cause="AWS Batch Job Failed",
        #     error="DescribeJob returned FAILED"
        # )

        # is_complete = sfn.Choice(
        #     self, "Job Complete?"
        # )

        definition = tes_task \
            .next(tes_task2) \
            .next(tes_task3)

        sfn.StateMachine(
            self, 
            "ShowcaseSfnStateMachine",
            definition=definition,
        )

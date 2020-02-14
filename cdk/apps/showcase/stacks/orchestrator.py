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

        # IAM roles for the lambda functions
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
                'TASK_VERSION': 'tvn:0ee81865bf514b7bb7b7ea305c88191f',
                # 'TASK_VERSION': 'tvn.b4735419fbe4455eb2b91960e48921f9',  # echo task
                'SSM_PARAM_JWT': props['ssm_param_name'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': 'umccr/alpine_pandas',
                'IMAGE_TAG': '1.0.1',
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
                'TASK_VERSION': 'tvn.ab3e85f9aaf24890ad169fdab3825c0d',
                # 'TASK_VERSION': 'tvn.b4735419fbe4455eb2b91960e48921f9',  # echo task
                'SSM_PARAM_JWT': props['ssm_param_name'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': '699120554104.dkr.ecr.us-east-1.amazonaws.com/public/dragen',
                'IMAGE_TAG': '3.5.2',
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
                'TASK_VERSION': 'tvn:f90aa88da2fe490fb6e6366b65abe267',
                # 'TASK_VERSION': 'tvn.b4735419fbe4455eb2b91960e48921f9',  # echo task
                'SSM_PARAM_JWT': props['ssm_param_name'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': 'umccr/alpine_pandas',
                'IMAGE_TAG': '1.0.1',
                'TES_TASK_NAME': 'FastqMapper'
            }
        )

        gather_samples_function = lmbda.Function(
            self,
            'GatherSamplesTesLambda',
            function_name='showcase_gather_samples_iap_tes_lambda_dev',
            handler='gather_samples.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas'),
            role=lambda_role,
            timeout=core.Duration.seconds(20),
            environment={
                'IAP_API_BASE_URL': props['iap_api_base_url'],
                'SSM_PARAM_JWT': props['ssm_param_name']
            }
        )

        dragen_function = lmbda.Function(
            self,
            'DragenTesLambda',
            function_name='showcase_dragen_iap_tes_lambda_dev',
            handler='launch_tes_task.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas'),
            role=lambda_role,
            timeout=core.Duration.seconds(20),
            environment={
                'IAP_API_BASE_URL': props['iap_api_base_url'],
                'TASK_ID': props['task_id'],
                'TASK_VERSION': 'tvn:096b39e90e4443abae0333e23fcabc61',
                # 'TASK_VERSION': 'tvn.b4735419fbe4455eb2b91960e48921f9',  # echo task
                'SSM_PARAM_JWT': props['ssm_param_name'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': '699120554104.dkr.ecr.us-east-1.amazonaws.com/public/dragen',
                'IMAGE_TAG': '3.5.2',
                'TES_TASK_NAME': 'Dragen'
            }
        )

        multiqc_function = lmbda.Function(
            self,
            'MultiQcTesLambda',
            function_name='showcase_multiqc_iap_tes_lambda_dev',
            handler='launch_tes_task.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas'),
            role=lambda_role,
            timeout=core.Duration.seconds(20),
            environment={
                'IAP_API_BASE_URL': props['iap_api_base_url'],
                'TASK_ID': props['task_id'],
                'TASK_VERSION': '983a0239483d4253a8a0531fa1de0376',
                # 'TASK_VERSION': 'tvn.b4735419fbe4455eb2b91960e48921f9',  # echo task
                'SSM_PARAM_JWT': props['ssm_param_name'],
                'GDS_LOG_FOLDER': props['gds_log_folder'],
                'IMAGE_NAME': 'umccr/multiqc_dragen',
                'IMAGE_TAG': '1.1',
                'TES_TASK_NAME': 'MultiQC'
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
        secret_value.grant_read(bcl_convert_function)
        secret_value.grant_read(fastq_mapper_function)
        secret_value.grant_read(gather_samples_function)
        secret_value.grant_read(dragen_function)
        secret_value.grant_read(multiqc_function)

        # SFN task definitions
        task_samplesheet_mapper = sfn.Task(
            self, "SampleSheetMapper",
            task=sfn_tasks.RunLambdaTask(
                samplesheet_mapper_function,
                integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
                payload={"taskCallbackToken": sfn.Context.task_token,
                         "runId.$": "$.runfolder"}),
            result_path="$.guid"
        )

        task_bcl_convert = sfn.Task(
            self, "BclConvert",
            task=sfn_tasks.RunLambdaTask(
                bcl_convert_function,
                integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
                payload={"taskCallbackToken": sfn.Context.task_token,
                         "runId.$": "$.runfolder"}),
            result_path="$.guid"
        )

        task_fastq_mapper = sfn.Task(
            self, "FastqMapper",
            task=sfn_tasks.RunLambdaTask(
                fastq_mapper_function,
                integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
                payload={"taskCallbackToken": sfn.Context.task_token,
                         "runId.$": "$.runfolder"}),
            result_path="$.guid"
        )

        task_gather_samples = sfn.Task(
            self, "GatherSamples",
            task=sfn_tasks.InvokeFunction(
                gather_samples_function,
                payload={"runId.$": "$.runfolder"}),
            result_path="$.sample_ids"
        )

        task_dragen = sfn.Task(
            self, "DragenTask",
            task=sfn_tasks.RunLambdaTask(
                dragen_function,
                integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
                payload={"taskCallbackToken": sfn.Context.task_token,
                         "runId.$": "$.runId",
                         "index.$": "$.index",
                         "item.$": "$.item"}),
            result_path="$.exit_status"
        )

        task_multiqc = sfn.Task(
            self, "MultiQcTask",
            task=sfn_tasks.RunLambdaTask(
                multiqc_function,
                integration_pattern=sfn.ServiceIntegrationPattern.WAIT_FOR_TASK_TOKEN,
                payload={"taskCallbackToken": sfn.Context.task_token,
                         "runId.$": "$.runfolder",
                         "samples.$": "$.sample_ids"})
        )

        scatter = sfn.Map(
            self, "Scatter",
            items_path="$.sample_ids",
            parameters={
                "index.$": "$$.Map.Item.Index",
                "item.$": "$$.Map.Item.Value",
                "runId.$": "$.runfolder"},
            result_path="$.mapresults",
            max_concurrency=3
        ).iterator(task_dragen)

        definition = task_samplesheet_mapper \
            .next(task_bcl_convert) \
            .next(task_fastq_mapper) \
            .next(task_gather_samples) \
            .next(scatter) \
            .next(task_multiqc)

        sfn.StateMachine(
            self,
            "ShowcaseSfnStateMachine",
            definition=definition,
        )

from aws_cdk import (
    aws_lambda as _lambda,
    aws_iam as _iam,
    aws_sns as _sns,
    aws_sns_subscriptions as _sns_subs,
    aws_events as _events,
    aws_events_targets as _events_targets,
    core
)


class IapLambdaStack(core.Stack):

    illumina_iap_account = '079623148045'

    def __init__(self, scope: core.Construct, id: str, slack_channel: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        lambda_role = _iam.Role(
            self,
            'SlackLambdaRole',
            assumed_by=_iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                _iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMReadOnlyAccess'),
                _iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')
            ]
        )

        function = _lambda.Function(
            self,
            'IapSlackLambda',
            handler='notify_slack.lambda_handler',
            runtime=_lambda.Runtime.PYTHON_3_7,
            code=_lambda.Code.asset('lambdas/iap'),
            environment={
                "SLACK_HOST": "hooks.slack.com",
                "SLACK_CHANNEL": slack_channel
            },
            role=lambda_role
        )

        sns_topic = _sns.Topic(
            self,
            'IapSnsTopic',
            display_name='IapSnsTopic',
            topic_name='IapSnsTopic'
        )
        sns_topic.grant_publish(_iam.AccountPrincipal(self.illumina_iap_account))
        sns_topic.add_subscription(_sns_subs.LambdaSubscription(function))


class BatchLambdaStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, slack_channel: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        lambda_role = _iam.Role(
            self,
            'SlackLambdaRole',
            assumed_by=_iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                _iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMReadOnlyAccess'),
                _iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')
            ]
        )

        function = _lambda.Function(
            self,
            'BatchSlackLambda',
            handler='notify_slack.lambda_handler',
            runtime=_lambda.Runtime.PYTHON_3_7,
            code=_lambda.Code.asset('lambdas/batch'),
            environment={
                "SLACK_HOST": "hooks.slack.com",
                "SLACK_CHANNEL": slack_channel
            },
            role=lambda_role
        )

        job_queue_eb_prefixes = [
            'cdk-umccrise_job_queue',
            'cttso-ica-to-pieriandx-',
            'gpl-job-queue',
            'nextflow-pipeline-ondemand',
            'wts_report_batch_queue_',
        ]

        job_queue_eb_patterns = list()
        for job_queue_eb_prefix in job_queue_eb_prefixes:
            pattern = f'arn:aws:batch:{self.region}:{self.account}:job-queue/{job_queue_eb_prefix}'
            job_queue_eb_patterns.append(pattern)

        _events.Rule(
            self,
            f'BatchEventToSlackLambda',
            event_pattern=_events.EventPattern(
                detail={
                    'status': [
                        'FAILED',
                        'SUCCEEDED',
                        'RUNNABLE',
                    ],
                    'jobQueue': [{'prefix': s} for s in job_queue_eb_patterns],
                },
                detail_type=['Batch Job State Change'],
                source=['aws.batch'],
            ),
            targets=[_events_targets.LambdaFunction(handler=function)]
        )

from aws_cdk import (
    aws_lambda as _lambda,
    aws_iam as _iam,
    aws_codebuild as cb,
    aws_sns as _sns,
    aws_sns_subscriptions as _sns_subs,
    aws_events_targets as targets,
    core
)


class CodeBuildLambdaStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        ################################################################################
        # Create a Lambda function to process the CodeBuild state change events
        # and send out appropriate Slack messages

        # Permissions for the Lambda
        lambda_role = _iam.Role(
            self,
            id='UmccriseCodeBuildSlackLambdaRole',
            assumed_by=_iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                _iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMReadOnlyAccess'),
                _iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole'),
                _iam.ManagedPolicy.from_aws_managed_policy_name('AmazonEC2ContainerRegistryReadOnly')
            ]
        )

        # The Lambda function itself
        function = _lambda.Function(
            self,
            id='UmccriseCodeBuildSlackLambda',
            handler='notify_slack.lambda_handler',
            runtime=_lambda.Runtime.PYTHON_3_7,
            code=_lambda.Code.asset('lambdas/slack'),
            environment={
                'SLACK_HOST': 'hooks.slack.com',
                'SLACK_CHANNEL': props['slack_channel'],
                'ECR_NAME': props['ecr_name'],
                'AWS_ACCOUNT': props['aws_account']  # TODO: get from kwargs (env)
            },
            role=lambda_role
        )

        ################################################################################
        # Create a reference to the UMCCRise CodeBuild project
        # TODO: should probably use cross-stack resource references
        cb_project = cb.Project.from_project_name(
            self,
            id='UmccriseCodeBuildProject',
            project_name=props['codebuild_project_name']
        )

        ################################################################################
        # Create an SNS topic to receive CodeBuild state change events
        sns_topic = _sns.Topic(
            self,
            id='UmccriseCodeBuildSnsTopic',
            display_name='UmccriseCodeBuildSnsTopic',
            topic_name='UmccriseCodeBuildSnsTopic'
        )
        sns_topic.grant_publish(cb_project)
        sns_topic.add_subscription(_sns_subs.LambdaSubscription(function))

        # Send state change events to SNS topic
        cb_project.on_state_change(
            id='UmccriseCodebuildStateChangeRule',
            rule_name='UmccriseCodebuildStateChangeRule',
            target=targets.SnsTopic(sns_topic)
        )

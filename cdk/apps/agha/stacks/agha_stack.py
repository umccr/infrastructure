from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    aws_s3 as s3,
    aws_sns as sns,
    aws_sns_subscriptions as sns_subs,
    core
)


class AghaStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, props: dict, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        ################################################################################
        # S3 Buckets
        # NOTE: CDK does currently not support event notification setup on imported/existing S3 buckets.
        #       The S3 event notification setup will have to be handled in Terraform as long as TF is controlling
        #       the S3 buckets.

        staging_bucket = s3.Bucket.from_bucket_name(
            self,
            id="GdrStagingBucket",
            bucket_name=props['staging_bucket']
        )
        store_bucket = s3.Bucket.from_bucket_name(
            self,
            id="GdrStoreBucket",
            bucket_name=props['store_bucket']
        )

        ################################################################################
        # Lambda general

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

        ################################################################################
        # Validation Lambda

        validation_lambda_role = iam.Role(
            self,
            'ValidationLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole'),
                iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMReadOnlyAccess'),
                iam.ManagedPolicy.from_aws_managed_policy_name('AmazonS3ReadOnlyAccess'),
                iam.ManagedPolicy.from_aws_managed_policy_name('IAMReadOnlyAccess')
            ]
        )
        validation_lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "ses:SendEmail",
                    "ses:SendRawEmail"
                ],
                resources=["*"]
            )
        )

        validation_lambda = lmbda.Function(
            self,
            'ValidationLambda',
            function_name=f"{props['namespace']}_validation_lambda",
            handler='validation.handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            timeout=core.Duration.seconds(10),
            code=lmbda.Code.from_asset('lambdas/validation'),
            environment={
                'STAGING_BUCKET': staging_bucket.bucket_name,
                'SLACK_HOST': props['slack_host'],
                'SLACK_CHANNEL': props['slack_channel'],
                'MANAGER_EMAIL': props['manager_email'],
                'SENDER_EMAIL': props['sender_email']
            },
            role=validation_lambda_role,
            layers=[
                pandas_layer,
                scipy_layer
            ]
        )

        ################################################################################
        # S3 event recorder Lambda

        s3_event_recorder_lambda_role = iam.Role(
            self,
            'S3EventRecorderLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole'),
                iam.ManagedPolicy.from_aws_managed_policy_name('AmazonDynamoDBFullAccess')
            ]
        )

        s3_event_recorder_lambda = lmbda.Function(
            self,
            'S3EventRecorderLambda',
            function_name=f"{props['namespace']}_s3_event_recorder_lambda",
            handler='s3_event_recorder.handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            timeout=core.Duration.seconds(10),
            code=lmbda.Code.from_asset('lambdas/s3_event_recorder'),
            environment={
                'STAGING_BUCKET': staging_bucket.bucket_name,
                'STORE_BUCKET': store_bucket.bucket_name
            },
            role=s3_event_recorder_lambda_role
        )

        ################################################################################
        # Folder lock Lambda

        folder_lock_lambda_role = iam.Role(
            self,
            'FolderLockLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')
            ]
        )
        folder_lock_lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "s3:GetBucketPolicy",
                    "s3:PutBucketPolicy",
                    "s3:DeleteBucketPolicy"
                ],
                resources=[f"arn:aws:s3:::{staging_bucket.bucket_name}"]
            )
        )

        folder_lock_lambda = lmbda.Function(
            self,
            'FolderLockLambda',
            function_name=f"{props['namespace']}_folder_lock_lambda",
            handler='folder_lock.handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            timeout=core.Duration.seconds(10),
            code=lmbda.Code.from_asset('lambdas/folder_lock'),
            environment={
                'STAGING_BUCKET': staging_bucket.bucket_name
            },
            role=folder_lock_lambda_role
        )

        ################################################################################
        # S3 event router Lambda

        s3_event_router_lambda_role = iam.Role(
            self,
            'S3EventRouterLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')
            ]
        )
        s3_event_router_lambda_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "lambda:InvokeFunction"
                ],
                resources=[
                    folder_lock_lambda.function_arn,
                    validation_lambda.function_arn,
                    s3_event_recorder_lambda.function_arn
                ]
            )
        )

        s3_event_router_lambda = lmbda.Function(
            self,
            'S3EventRouterLambda',
            function_name=f"{props['namespace']}_s3_event_router_lambda",
            handler='s3_event_router.handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            timeout=core.Duration.seconds(20),
            code=lmbda.Code.from_asset('lambdas/s3_event_router'),
            environment={
                'STAGING_BUCKET': staging_bucket.bucket_name,
                'VALIDATION_LAMBDA_ARN': validation_lambda.function_arn,
                'FOLDER_LOCK_LAMBDA_ARN': folder_lock_lambda.function_arn,
                'S3_RECORDER_LAMBDA_ARN': s3_event_recorder_lambda.function_arn
            },
            role=s3_event_router_lambda_role
        )

        ################################################################################
        # SNS topic
        # Not needed, as we can directly route S3 events to Lambda.
        # May be useful to filter out unwanted events in the future.

        # sns_topic = sns.Topic(
        #     self,
        #     id="AghaS3EventTopic",
        #     topic_name="AghaS3EventTopic",
        #     display_name="AghaS3EventTopic"
        # )
        # sns_topic.add_subscription(subscription=sns_subs.LambdaSubscription(fn=s3_event_router_lambda))


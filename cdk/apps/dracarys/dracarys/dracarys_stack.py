# Originally authored by @andrei-seleznev in https://github.com/umccr/dracarys-to-s3-cdk

from aws_cdk import (
    aws_lambda,
    aws_iam,
    aws_s3,
    aws_sqs,
    aws_ssm,
    aws_lambda_event_sources as lambda_event_source,
    aws_cloudwatch as cloudwatch,
    aws_chatbot as chatbot,
    Stack,
    Duration
)

from constructs import Construct

ENV = "prod"

class DracarysStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        lambda_role = aws_iam.Role(scope=self, id='dracarys-lambda-role',
                                assumed_by =aws_iam.ServicePrincipal('lambda.amazonaws.com'),
                                role_name='dracarys-lambda-role',
                                managed_policies=[
                                aws_iam.ManagedPolicy.from_aws_managed_policy_name(
                                    'service-role/AWSLambdaBasicExecutionRole'),
                                aws_iam.ManagedPolicy.from_aws_managed_policy_name(
                                    'service-role/AWSLambdaVPCAccessExecutionRole'),
                                aws_iam.ManagedPolicy.from_aws_managed_policy_name(
                                    'SecretsManagerReadWrite'),
                                aws_iam.ManagedPolicy.from_aws_managed_policy_name(
                                    'AmazonS3FullAccess')
                                ])

        # Fetch dracarys queue ARN from pre-existing SSM
        # created by terraform's data portal pipeline stack
        queue_name = "/data_portal/backend/sqs_dracarys_queue"
        queue_arn = aws_ssm.StringParameter.from_string_parameter_attributes(self, "dracarys_sqs_queue",
                parameter_name=queue_name).string_value

        queue = aws_sqs.Queue.from_queue_arn(self, id="data-portal-dracarys-queue", queue_arn=queue_arn)

        bucket = aws_s3.Bucket(self, "umccr-datalake-"+ENV)

        sqs_event_source = lambda_event_source.SqsEventSource(queue)

        docker_lambda = aws_lambda.DockerImageFunction(
            self, 'dracarys-ingestion-lambda',
            function_name='dracarys-ingestion-lambda',
            description='dracarys lambda',
            code=aws_lambda.DockerImageCode.from_image_asset(
                directory="./lambda"
            ),
            role=lambda_role,
            timeout=Duration.minutes(15),
            memory_size=4096,
            environment={
                'NAME': 'dracarys-ingestion-lambda'
            },
        )

        docker_lambda.add_event_source(sqs_event_source)
        bucket.grant_read_write(docker_lambda)

        metric = docker_lambda.metric("Error")
        metric.create_alarm(self, "Dracarys failure",
                            threshold=100,
                            evaluation_periods=3,
                            datapoints_to_alarm=1
        )

        target = chatbot.SlackChannelConfiguration(self, "UMCCR Slack chatbot",
            slack_channel_configuration_name="biobots",
            slack_workspace_id="",
            slack_channel_id=""
        )

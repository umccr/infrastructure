from aws_cdk import (
    aws_lambda,
    aws_iam,
    aws_sqs,
    aws_apigateway,
    aws_lambda_event_sources as lambda_event_source,
    Stack,
    Duration
)

from constructs import Construct

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
                                    'SecretsManagerReadWrite')
                                ])


        cdk_lambda = aws_lambda.DockerImageFunction(
            self, 'dracarys-ingestion-lambda',
            function_name='dracarys-ingestion-lambda',
            description='dracarys lambda',
            code=aws_lambda.DockerImageCode.from_image_asset(
                directory="./lambda"
            ),
            role=lambda_role,
            timeout=Duration.minutes(15),
            memory_size=512,
            environment={
                'NAME': 'dracarys-ingestion-lambda'
            }
        )

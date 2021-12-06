from aws_cdk import (
    aws_lambda as _lambda
)
    
from aws_cdk import core

class AwsLambdaContainerCdkRStack(core.Stack):

    def __init__(self, scope: core.Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # The code that defines your stack goes here
        function = _lambda.DockerImageFunction(self, "lambda_function",
                                    code=_lambda.DockerImageCode.from_image_asset("./assets"))

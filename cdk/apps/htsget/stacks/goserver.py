from aws_cdk import (
    core,
    aws_lambda as _lambda,
    aws_apigateway as _apigw
)

UMCCR_HTSGET_DOMAIN="htsget.umccr.org"

class GoServerStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        base_lambda = _lambda.Function(self,'ApiGatewayHtsget',
        handler='lambda-handler.handler',
        runtime=_lambda.Runtime.PYTHON_3_8,
        code=_lambda.Code.asset('lambda'),
        )


        api = _apigw.SpecRestApi(self, "htsget-openapi.yaml",
                                api_definition=_apigw.ApiDefinition.from_asset("htsget-openapi.yaml"))

    #     self.add_cors_options(example_entity)

    # def add_cors_options(self, apigw_resource):
    #     apigw_resource.add_method('OPTIONS', _apigw.MockIntegration(
    #         integration_responses=[{
    #             'statusCode': '200',
    #             'responseParameters': {
    #                 'method.response.header.Access-Control-Allow-Headers': "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    #                 'method.response.header.Access-Control-Allow-Origin': "$UMCCR_HTSGET_DOMAIN",
    #                 'method.response.header.Access-Control-Allow-Methods': "'GET,OPTIONS'"
    #             }
    #         }
    #         ],
    #         passthrough_behavior=_apigw.PassthroughBehavior.WHEN_NO_MATCH,
    #         request_templates={"application/json":"{\"statusCode\":200}"}
    #     ),
    #     method_responses=[{
    #         'statusCode': '200',
    #         'responseParameters': {
    #             'method.response.header.Access-Control-Allow-Headers': True,
    #             'method.response.header.Access-Control-Allow-Methods': True,
    #             'method.response.header.Access-Control-Allow-Origin': True,
    #             }
    #         }
    #     ],
    # )

app = core.App()
app.synth()

from constructs import Construct
from aws_cdk import (
    Duration,
    Stack,
    aws_events as events,
    aws_events_targets as targets,
    aws_iam as iam,
    aws_lambda as lmbda,
    aws_sqs as sqs
)
# from aws_solutions_constructs import (
#     aws_sqs_lambda
# )
from re import sub
from lambdas.layers.eb_util.eb_util import EventType, EventSource


def camel_case_upper(string: str):
  string = sub(r"([_\-])+", " ", string).title().replace(" ", "")
  return string


class TheBusStack(Stack):

    namespace = None

    def __init__(self, scope: Construct, construct_id: str, props: dict, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.namespace = props['namespace']  # namespace in camelcase

        ################################################################################
        # Event Bus

        event_bus_name = "DataPortalEventBus"
        event_bus = events.EventBus(scope=self, id="umccr_bus", event_bus_name=event_bus_name)

        # Creates GDS SQS queue for Illumina file events
        sqs_queue = sqs.Queue(scope=self, id="UmccrEventBusIcaEnsQueue")
        sqs_queue.grant_send_messages(iam.AccountPrincipal('079623148045'))

        ################################################################################
        # Lambda

        # Lambda layers for shared libs
        util_lambda_layer = self.create_lambda_layer(scope=self, name="eb_util")

        # lambda environment variables
        lambda_env = {
            "EVENT_BUS_NAME": event_bus_name
        }

        orchestrator_lambda = self.create_standard_lambda(scope=self, name="orchestrator", layers=[util_lambda_layer], env=lambda_env)
        bcl_convert_lambda = self.create_standard_lambda(scope=self, name="bcl_convert", layers=[util_lambda_layer])
        dragen_wgs_qc_lambda = self.create_standard_lambda(scope=self, name="dragen_wgs_qc", layers=[util_lambda_layer])
        dragen_wgs_somatic_lambda = self.create_standard_lambda(scope=self, name="dragen_wgs_somatic", layers=[util_lambda_layer])
        wes_launcher_lambda = self.create_standard_lambda(scope=self, name="wes_launcher", layers=[util_lambda_layer])
        gds_lambda = self.create_standard_lambda(scope=self, name="gds", layers=[util_lambda_layer])

        ################################################################################
        # Event Rules setup

        # set up event rules
        rule = events.Rule(scope=self,
                           id="BclConvertRule",
                           rule_name="BclConvertRule",
                           description="Rule to send BCL CONVERT events to the BCL CONVERT Lambda",
                           event_bus=event_bus)
        rule.add_target(target=targets.LambdaFunction(handler=bcl_convert_lambda))
        rule.add_event_pattern(detail_type=[EventType.BCL_CONVERT.value],
                               source=[EventSource.ORCHESTRATOR.value])

    def create_standard_lambda(self, scope, name: str, layers: list = [], env: dict = {}, duration_seconds: int = 20):
        id = camel_case_upper(f"{self.namespace}_{name}_Lambda")
        function_name = f"{self.namespace}_{name}"
        # TODO: switch to aws_cdk.aws_lambda_python -> PythonFunction
        return lmbda.Function(scope=scope,
                              id=id,
                              function_name=function_name,
                              handler=f"{name}.handler",
                              runtime=lmbda.Runtime.PYTHON_3_8,
                              code=lmbda.Code.from_asset(f"lambdas/functions/{name}"),
                              environment=env,
                              timeout=Duration.seconds(duration_seconds),
                              layers=layers)

    def create_lambda_layer(self, scope, name: str) -> lmbda.LayerVersion:
        # NOTE: currently requires manual packaging
        # TODO: switch to aws_cdk.aws_lambda_python -> PythonLayerVersion
        id = camel_case_upper(f"{self.namespace}_{name}_Layer")
        return lmbda.LayerVersion(
            scope=scope,
            id=id,
            code=lmbda.Code.from_asset(f"lambdas/layers/{name}/{name}.zip"),
            compatible_runtimes=[lmbda.Runtime.PYTHON_3_8],
            description=f"Lambda layer {name} for python 3.8"
        )


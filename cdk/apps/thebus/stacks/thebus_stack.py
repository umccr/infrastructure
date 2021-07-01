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
        # TODO: change id, use namespace as basis
        event_bus = events.EventBus(scope=self,
                                    id="umccr_bus",
                                    event_bus_name=event_bus_name)

        # Creates GDS SQS queue for Illumina file events
        # sqs_queue = sqs.Queue(scope=self, id="UmccrEventBusIcaEnsQueue")
        # sqs_queue.grant_send_messages(iam.AccountPrincipal('079623148045'))

        ################################################################################
        # Lambda

        # Lambda layers for shared libs
        util_lambda_layer = self.create_lambda_layer(scope=self, name="eb_util")
        # TODO: needs more investigation as integration is not straight forward
        schema_lambda_layer = self.create_lambda_layer(scope=self, name="schemas")

        # lambda environment variables
        lambda_env = {
            "EVENT_BUS_NAME": event_bus_name
        }

        # Lambda to manage workflow events
        orchestrator_lambda = self.create_standard_lambda(scope=self, name="orchestrator", layers=[util_lambda_layer, schema_lambda_layer], env=lambda_env)
        event_bus.grant_put_events_to(orchestrator_lambda)

        # Lambda to prepare BCL Convert workflows
        bcl_convert_lambda = self.create_standard_lambda(scope=self, name="bcl_convert", layers=[util_lambda_layer, schema_lambda_layer], env=lambda_env)
        event_bus.grant_put_events_to(bcl_convert_lambda)

        # Lambda to prepare WGS QC workflows
        dragen_wgs_qc_lambda = self.create_standard_lambda(scope=self, name="dragen_wgs_qc", layers=[util_lambda_layer, schema_lambda_layer], env=lambda_env)
        event_bus.grant_put_events_to(dragen_wgs_qc_lambda)

        # Lambda to prepare WGS somatic analysis workflows
        dragen_wgs_somatic_lambda = self.create_standard_lambda(scope=self, name="dragen_wgs_somatic", layers=[util_lambda_layer, schema_lambda_layer], env=lambda_env)
        event_bus.grant_put_events_to(dragen_wgs_somatic_lambda)

        # Lambda to submit WES workflows to ICA
        wes_launcher_lambda = self.create_standard_lambda(scope=self, name="wes_launcher", layers=[util_lambda_layer, schema_lambda_layer])
        event_bus.grant_put_events_to(wes_launcher_lambda)

        # Lambda to handle GDS events (translating outside events into application events + dedup/persisting)
        gds_manager_lambda = self.create_standard_lambda(scope=self, name="gds_manager", layers=[util_lambda_layer])
        event_bus.grant_put_events_to(gds_manager_lambda)

        # Lamda to handle ENS events (translating outside events into application events + dedup/persisting)
        ens_manager_lambda = self.create_standard_lambda(scope=self, name="ens_event_manager", layers=[util_lambda_layer, schema_lambda_layer], env=lambda_env)
        event_bus.grant_put_events_to(ens_manager_lambda)
        ens_manager_lambda.grant_invoke(wes_launcher_lambda)

        ################################################################################
        # Event Rules setup

        # set up event rules
        # TODO: change id/name, use namespace as basis
        wes_rule = events.Rule(
            scope=self,
            id="WesRule",
            rule_name="WesRule",
            description="Rule to send WES events to the orchestrator Lambda",
            event_bus=event_bus)
        wes_rule.add_target(target=targets.LambdaFunction(handler=orchestrator_lambda))
        wes_rule.add_event_pattern(detail_type=[EventType.WES.value],
                                   source=[EventSource.WES.value])

        bssh_rule = events.Rule(
            scope=self,
            id="BsshRule",
            rule_name="BsshRule",
            description="Rule to send BSSH events to the orchestrator Lambda",
            event_bus=event_bus)
        bssh_rule.add_target(target=targets.LambdaFunction(handler=orchestrator_lambda))
        bssh_rule.add_event_pattern(detail_type=[EventType.SRSC.value],
                                    source=[EventSource.ENS_HANDLER.value])

        orch_to_bcl_convert_rule = events.Rule(
            scope=self,
            id="BclConvertRule",
            rule_name="BclConvertRule",
            description="Rule to send BCL_CONVERT events from the orchestrator to the bcl_convert Lambda",
            event_bus=event_bus)
        orch_to_bcl_convert_rule.add_target(target=targets.LambdaFunction(handler=bcl_convert_lambda))
        orch_to_bcl_convert_rule.add_event_pattern(detail_type=[EventType.SRSC.value],
                                                   source=[EventSource.ORCHESTRATOR.value])

        orch_to_wgs_qc_rule = events.Rule(
            scope=self,
            id="DragenWgsQcRule",
            rule_name="DragenWgsQcRule",
            description="Rule to send DRAGEN_WGS_QC events from the orchestrator to the dragen_wgs_qc Lambda",
            event_bus=event_bus)
        orch_to_wgs_qc_rule.add_target(target=targets.LambdaFunction(handler=dragen_wgs_qc_lambda))
        orch_to_wgs_qc_rule.add_event_pattern(detail_type=[EventType.DRAGEN_WGS_QC.value],
                                              source=[EventSource.ORCHESTRATOR.value])

        orch_to_wgs_somatic_rule = events.Rule(
            scope=self,
            id="DragenWgsSomaticRule",
            rule_name="DragenWgsSomaticRule",
            description="Rule to send DRAGEN_WGS_SOMATIC events from the orchestrator to the dragen_wgs_somatic Lambda",
            event_bus=event_bus)
        orch_to_wgs_somatic_rule.add_target(target=targets.LambdaFunction(handler=dragen_wgs_somatic_lambda))
        orch_to_wgs_somatic_rule.add_event_pattern(detail_type=[EventType.DRAGEN_WGS_SOMATIC.value],
                                                   source=[EventSource.ORCHESTRATOR.value])

        bcl_convert_to_wes_launcher_rule = events.Rule(
            scope=self,
            id="BclConvertLaunchRule",
            rule_name="BclConvertLaunchRule",
            description="Rule to send BCL_CONVERT launch events to the wes_launcher Lambda",
            event_bus=event_bus)
        bcl_convert_to_wes_launcher_rule.add_target(target=targets.LambdaFunction(handler=wes_launcher_lambda))
        bcl_convert_to_wes_launcher_rule.add_event_pattern(detail_type=[EventType.WES_LAUNCH.value],
                                                           source=[EventSource.BCL_CONVERT.value])

        wgs_qc_to_wes_launcher_rule = events.Rule(
            scope=self,
            id="DragenWgsQcLaunchRequestRule",
            rule_name="DragenWgsQcLaunchRequestRule",
            description="Rule to send DRAGEN_WGS_QC launch events to the wes_launcher Lambda",
            event_bus=event_bus)
        wgs_qc_to_wes_launcher_rule.add_target(target=targets.LambdaFunction(handler=wes_launcher_lambda))
        wgs_qc_to_wes_launcher_rule.add_event_pattern(detail_type=[EventType.WES_LAUNCH.value],
                                                      source=[EventSource.DRAGEN_WGS_QC.value])

        wgs_somatic_to_wes_launcher_rule = events.Rule(
            scope=self,
            id="DragenWgsSomaticLaunchRule",
            rule_name="DragenWgsSomaticLaunchRule",
            description="Rule to send DRAGEN_WGS_SOMATIC launch events to the wes_launcher Lambda",
            event_bus=event_bus)
        wgs_somatic_to_wes_launcher_rule.add_target(target=targets.LambdaFunction(handler=wes_launcher_lambda))
        wgs_somatic_to_wes_launcher_rule.add_event_pattern(detail_type=[EventType.WES_LAUNCH.value],
                                                           source=[EventSource.DRAGEN_WGS_SOMATIC.value])

    # TODO: refactor to allow separate function path/name (allow better code organisation)
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
            code=lmbda.Code.from_asset(f"lambdas/layers/{name}.zip"),
            compatible_runtimes=[lmbda.Runtime.PYTHON_3_8],
            description=f"Lambda layer {name} for python 3.8"
        )

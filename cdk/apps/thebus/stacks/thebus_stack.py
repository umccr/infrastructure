from constructs import Construct
from aws_cdk import Stack
from aws_cdk import aws_events as events
from aws_cdk import aws_events_targets as targets
from aws_cdk import (
    Duration,
    aws_lambda as _lambda,
    aws_stepfunctions as sfn,
    aws_stepfunctions_tasks as sfn_tasks,
    aws_sqs as sqs
)
import typing

class TheBusStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # 0) Create GDS SQS queue for Illumina file events

        gds_file_events = sqs.Queue(self, id="umccr-bus-dev-iap-ens-event-queue")
            # This queue will receive events from Illumina's ICA/GDS object store system and shall be subscribed accordingly:
            #
            # ica subscriptions create \ 
            #   --name "UMCCREventBridgeBus" 
            #   --type "gds.files" --actions "uploaded,deleted,archived,unarchived" 
            #   --description "UMCCR Event Bus (DEV) subscribed to gds.files events using the development project" 
            #   --aws-sqs-queue "https://sqs.ap-southeast-2.amazonaws.com/<ACCOUNT_ID>/umccr-bus-dev-iap-ens-event-queue" 
            #   --filter-expression "{\"or\":[{\"equal\":[{\"path\":\"$.volumeName\"},\"umccr-example-GDS-volume\"]}]}"

        # 1) deploy lambda function
        pipeline = TheBusStack.lambdaDeploy(self)

        # 2) prepare resources EventBus, EventPattern, Rule-Target
        eventBus, eventPattern, lambdaTarget1 = TheBusStack.createEventBusAndEventPatternAndLambdaTarget(self, pipeline)

        # 3) create step functions StateMachine
        stateMachineTarget = TheBusStack.createReportsIngestionStateMachine(self, pipeline)

        # 4) create rule using resources: EventBus, EventPattern, Rule-Targets: Lambda and State-Machine
        TheBusStack.createRule(self, [lambdaTarget1, stateMachineTarget], eventBus, eventPattern)

    # -----------------------------------------------------------------------------------

    @staticmethod
    def lambdaDeploy(this) -> None:
        pipeline = _lambda.Function(this, 'reports_ingestor',
                                       function_name='reports_ingestor',
                                       handler='reports.handler',
                                       runtime=_lambda.Runtime.PYTHON_3_8,
                                       code=_lambda.Code.from_asset('lambdas'),
                                       timeout=Duration.seconds(20),
                                    )
        return pipeline
    # -----------------------------------------------------------------------------------
    @staticmethod
    def createEventBusAndEventPatternAndLambdaTarget(this, pipeline: _lambda.IFunction):
        eventBus      = events.EventBus(scope=this, id="umccr_bus", event_bus_name="umccr_bus")
        eventPattern  = events.EventPattern(source=['reports'])
        lambdaTarget1 = targets.LambdaFunction(handler=pipeline)

        return eventBus, eventPattern, lambdaTarget1
    # -----------------------------------------------------------------------------------
    @staticmethod
    def createRule(this, targetsList : typing.Optional[typing.List["IRuleTarget"]] = None, 
                         eventBus: typing.Optional["IEventBus"]=None, 
                         eventPattern: typing.Optional["EventPattern"]=None):
        events.Rule(scope=this,
                    id="reports_trigger",
                    rule_name="reports_ingestion",
                    targets=targetsList,
                    description="Rule",
                    event_bus=eventBus,
                    event_pattern=eventPattern,
                    )
    # -----------------------------------------------------------------------------------
    @staticmethod
    def createReportsIngestionStateMachine(this, lambda_function: _lambda.IFunction):
        submit_job_activity = sfn.Activity(
            this, "IngestReport"
        )

        submit_job = sfn_tasks.LambdaInvoke(
            this,
            "Submit report",
            lambda_function=lambda_function,
            input_path="$.input",
        )

        # definition = submit_job.next(get_status).end_states(sfn.Succeed())
        definition = submit_job

        machineHandler = sfn.StateMachine(
            this, "ReportsIngestor",
            definition=definition,
            state_machine_name="ReportsIngestor",
            timeout=Duration.seconds(30),
        )
        #  machine: aws_cdk.aws_stepfunctions.IStateMachine
        stateMachineTarget = targets.SfnStateMachine(machine=machineHandler)
        return  stateMachineTarget

    # ----------------------------------------------------------------------------------- 

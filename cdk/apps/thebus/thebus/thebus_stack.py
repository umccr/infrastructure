from aws_cdk import aws_events as events
from aws_cdk import aws_events_targets as targets
from aws_cdk import (
    aws_lambda as _lambda,
    aws_stepfunctions as sfn,
    aws_stepfunctions_tasks as sfn_tasks
)
from aws_cdk import core
import typing

class TheBusStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

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
                                       handler='lambda_handler',
                                       runtime=_lambda.Runtime.PYTHON_3_7,
                                       code=_lambda.Code.asset('../lambdas/reports_ingestor.py'),
                                       )
        return pipeline
    # -----------------------------------------------------------------------------------
    @staticmethod
    def createEventBusAndEventPatternAndLambdaTarget(this, pipeline: _lambda.IFunction):
        eventBus      = events.EventBus(scope=this, id="umccr", event_bus_name="umccr")
        eventPattern  = events.EventPattern(source=['reports'])
        lambdaTarget1 = targets.LambdaFunction(handler=pipeline)

        return eventBus, eventPattern, lambdaTarget1
    # -----------------------------------------------------------------------------------
    @staticmethod
    def createRule(this, targetsList : typing.Optional[typing.List["IRuleTarget"]] = None, eventBus: typing.Optional["IEventBus"]=None, eventPattern: typing.Optional["EventPattern"]=None):
        events.Rule(scope=this,
                    id="x123",
                    rule_name="routeToLambda",
                    targets=targetsList,
                    description="cdk Test Rule navigates to Lambda",
                    event_bus=eventBus,
                    event_pattern=eventPattern,
                    )
    # -----------------------------------------------------------------------------------
    @staticmethod
    def createReportsIngestionStateMachine(this, lambda_function: _lambda.IFunction):
        submit_job_activity = sfn.Activity(
            this, "IngestReport"
        )

        submit_job = sfn.Task(
            this, "Submit Job",
            # task=sfn_tasks.InvokeActivity(submit_job_activity),
            task=sfn_tasks.InvokeFunction(lambda_function),
            result_path="$.guid",
        )

        finalStatus =  sfn.Succeed(
            this, 'Final Job Status'
        )

        # definition = submit_job.next(get_status).end_states(sfn.Succeed())
        definition = submit_job\
                     .next(finalStatus)

        machineHandler = sfn.StateMachine(
            this, "ReportsIngestor",
            definition=definition,
            state_machine_name="ReportsIngestor",
            timeout=core.Duration.seconds(30),
        )
        #  machine: aws_cdk.aws_stepfunctions.IStateMachine
        stateMachineTarget = targets.SfnStateMachine(machine=machineHandler)
        return  stateMachineTarget

    # ----------------------------------------------------------------------------------- 

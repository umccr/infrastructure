from constructs import Construct
from aws_cdk import Stack
from aws_cdk import aws_events as events
from aws_cdk import aws_events_targets as targets
from aws_cdk import (
    Duration,
    aws_lambda as _lambda,
    aws_sqs as sqs,
    aws_iam as iam
)
import typing

class TheBusStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Creates GDS SQS queue for Illumina file events
        _ = sqs.Queue(self, id="umccr-bus-dev-iap-ens-event-queue") \
                              .grant_send_messages(iam.AccountPrincipal('079623148045'))
        lmbda_handler = TheBusStack.lambdaDeploy(self)
        eventBus = TheBusStack.createEventBus(self)
        eventPattern = TheBusStack.setEventPatternForSQS()
        lmbda_target = TheBusStack.setLambdaTarget(self, lmbda_handler)
        TheBusStack.createRule(self, [lmbda_target], eventBus, eventPattern)

    @staticmethod
    def lambdaDeploy(this) -> None:
        pipeline = _lambda.Function(this, 'gds',
                                       function_name='gds',
                                       handler='gds.lambda_handler',
                                       runtime=_lambda.Runtime.PYTHON_3_8,
                                       code=_lambda.Code.from_asset('lambdas/gds'),
                                       timeout=Duration.seconds(20),
                                    )
        return pipeline

    @staticmethod
    def createEventBus(this):
        return events.EventBus(scope=this, id="umccr_bus", event_bus_name="umccr_bus")

    @staticmethod
    def setEventPatternForSQS():
        return events.EventPattern(source=['aws.sqs'])
    
    @staticmethod
    def setLambdaTarget(self, lmbda_target: _lambda.IFunction):
        return targets.LambdaFunction(handler = lmbda_target)

    @staticmethod
    def createRule(this, targetsList : typing.Optional[typing.List["IRuleTarget"]] = None,
                         eventBus: typing.Optional["IEventBus"]=None, 
                         eventPattern: typing.Optional["EventPattern"]=None):
        events.Rule(scope=this,
                    id="gds_file_events_trigger",
                    rule_name="gds_files_events",
                    targets=targetsList,
                    description="Rule",
                    event_bus=eventBus,
                    event_pattern=eventPattern,
                    )

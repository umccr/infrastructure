from constructs import Construct
from aws_cdk import Stack
from aws_cdk import aws_events as events
from aws_cdk import aws_events_targets as targets
from aws_cdk import (
    aws_sqs as sqs,
    aws_iam as iam
)
import typing

class TheBusStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # 1) Create GDS SQS queue for Illumina file events
        gds_events_queue = sqs.Queue(self, id="umccr-bus-dev-iap-ens-event-queue") \
                              .grant_send_messages(iam.AccountPrincipal('079623148045'))

        # 2) prepare resources EventBus, EventPattern, Rule-Target
        eventBus, eventPattern = TheBusStack.createEventBusAndEventPatternForSQS(self, gds_events_queue)

        # 3) create rule using resources: EventBus, EventPattern, Rule-Targets: Lambda and State-Machine
        TheBusStack.createRule(self, eventBus, eventPattern)

    # -----------------------------------------------------------------------------------
    @staticmethod
    def createEventBusAndEventPatternForSQS(this, queue: sqs.Queue):
        eventBus      = events.EventBus(scope=this, id="umccr_bus", event_bus_name="umccr_bus")
        eventPattern  = events.EventPattern(source=['aws.sqs'])

        return eventBus, eventPattern
    # -----------------------------------------------------------------------------------
    @staticmethod
    def createRule(this, eventBus: typing.Optional["IEventBus"]=None, 
                         eventPattern: typing.Optional["EventPattern"]=None):
        events.Rule(scope=this,
                    id="gds_file_events_trigger",
                    rule_name="gds_files_events",
                    description="Rule",
                    event_bus=eventBus,
                    event_pattern=eventPattern,
                    )
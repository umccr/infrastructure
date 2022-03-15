import json
from constructs import Construct
from aws_cdk import (
    Stack,
    aws_eventschemas as schemas,

)


def get_schema_json_as_dict(file: str) -> dict:
    with open(file) as f:
        data = json.load(f)
    return data


class SchemaStack(Stack):
    
    namespace = None
    registry = None

    def __init__(self, scope: Construct, construct_id: str, props: dict, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.namespace = props['namespace']

        registry_name = f"{self.namespace}SchemaRegistry"
        self.registry = schemas.CfnRegistry(
            scope=self,
            id=registry_name,
            registry_name=registry_name,
            description="Schema registry for the UMCCR Data Portal Event Bus")

        # TODO: investigate use of custom event schema
        # According to the API (https://docs.aws.amazon.com/eventbridge/latest/APIReference/API_PutEvents.html)
        # events have to be wrapped into a defined AWSEvent format, with arbitrarily definable "Detail" (payload)
        # However, the event bus registry allows events to be defined and schemas created that do not follow that
        # convention. It is unclear how to consolidate those...
        # Also: import of autogenerated classes has its challenges:
        #       - how to pull
        #       - how to reference/build a lambda layer
        #       - objects are not JSON serializable and the use of Marshallers presents extra hurdles

        self.create_schema(name="SequenceRunStateChange")
        self.create_schema(name="WorkflowRunStateChange")
        self.create_schema(name="WesLaunchRequest")
        self.create_schema(name="WorkflowRequest")

    def create_schema(self, name):
        return schemas.CfnSchema(
            scope=self,
            id=f"{self.namespace}{name}Schema",
            schema_name=name,
            description=f"Schema representing a {name}",
            type="OpenApi3",
            registry_name=self.registry.attr_registry_name,
            content=json.dumps(get_schema_json_as_dict(f"schema/{name}.json")))
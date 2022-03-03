#!/usr/bin/env python3
from constructs import Construct
import aws_cdk as cdk

from stacks.thebus_stack import TheBusStack
from stacks.schema_stack import SchemaStack


props = {
    'namespace': 'UmccrEventBus'
}


app = cdk.App()

SchemaStack(scope=app,
            construct_id=f"{props['namespace']}SchemaStack",
            props=props)

# Bring up the organization event bus 
TheBusStack(scope=app,
            construct_id=props['namespace'],
            props=props)

app.synth()

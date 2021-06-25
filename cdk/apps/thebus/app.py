#!/usr/bin/env python3
from constructs import Construct
import aws_cdk as cdk

from stacks.thebus_stack import TheBusStack


props = {
    'namespace': 'UmccrEventBus'
}


app = cdk.App()

# Bring up the organization event bus 
TheBusStack(scope=app,
            construct_id=props['namespace'],
            props=props)

app.synth()

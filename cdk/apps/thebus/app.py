#!/usr/bin/env python3
from constructs import Construct
import aws_cdk as cdk

from stacks.thebus_stack import TheBusStack 

app = cdk.App()

# Bring up the organization event bus 
thebus_stack = TheBusStack(app, "TheBusStack")

app.synth()

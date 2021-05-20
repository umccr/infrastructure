#!/usr/bin/env python3

import sys
import os
from aws_cdk import core

from thebus.thebus_stack import TheBusStack 

app = core.App()

# Bring up the organization event bus 
thebus_stack = TheBusStack(app, "TheBus")

app.synth()

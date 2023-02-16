#!/usr/bin/env python3
import os
import aws_cdk as cdk

from dracarys.dracarys_stack import DracarysStack

app = cdk.App()
DracarysStack(app, "DracarysStack")

app.synth()

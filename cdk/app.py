#!/usr/bin/env python3
from aws_cdk import core
from umccrise.cicd import CICDStack

app = core.App()
CICDStack(app, "umccrise-cicd", env = {'region': 'ap-southeast-2'})

app.synth()

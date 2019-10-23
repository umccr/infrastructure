#!/usr/bin/env python3
from aws_cdk import core
from stacks.cicd import CICDStack

app = core.App()
CICDStack(app, "umccrise-cicd", env = {'account': '843407916570', 'region': 'ap-southeast-2'})

app.synth()

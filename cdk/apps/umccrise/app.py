#!/usr/bin/env python3
from aws_cdk import core
from stacks.cicd import CICDStack
from stacks.batch import BatchStack


batch_dev_props = {
    'namespace': 'umccrise-batch-dev',
    'container_image': 'umccr/umccrise:0.15.15'
}

app = core.App()
CICDStack(app, "umccrise-cicd", env={'account': '843407916570', 'region': 'ap-southeast-2'})
BatchStack(app, batch_dev_props['namespace'], batch_dev_props, env={'account': '843407916570', 'region': 'ap-southeast-2'})

app.synth()

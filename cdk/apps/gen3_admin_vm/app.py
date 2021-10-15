#!/usr/bin/env python3
import os
from aws_cdk import core

from admin_vm.admin_vm_stack import AdminVmStack, VmLookup


# Set tags for container
TAGS = {
    "Stack": "UoM-Gen3-AdminVm",
    "UseCase": "Gen3"
}


aws_env = {
    'account': os.environ.get('CDK_DEFAULT_ACCOUNT'),
    'region': os.environ.get('CDK_DEFAULT_REGION')
}

app = core.App()

# Build the dev stack
VmLookup(app, "VmLookupStack", env=aws_env)
AdminVmStack(app, "Gen3AdminVmStack", env=aws_env)

# Add tags to app
for key, value in TAGS.items():
    core.Tag.add(app, key, value)

app.synth()

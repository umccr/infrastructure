#!/usr/bin/env python3

import sys
import os
import uuid
import json

from aws_cdk import core

from dev_worker.dev_worker_stack import DevWorkerStack

# Set account vars
ACCOUNT = "843407916570"  # Dev
REGION = "ap-southeast-2"
CREATOR_NAME = "Alexis Lucattini"

# Set tags for container
TAGS = {
    "Stack": "DEV-CDK",
    "UseCase": "Testing-CDK",
    "Environment": "dev"
}

app = core.App()

# Check required args are not none
stack_name = app.node.try_get_context("STACK_NAME")

# Check stack name
if stack_name is None:
    user_name = os.environ.get('USER')
    # Check there is a user
    if not user_name:
        print("Error: no STACK_NAME defined!")
        print("Please use -c \"STACK_NAME=name-of-stack\" or set the $USER env variable.")
        sys.exit(1)

    # Define the stack name
    stack_name = "dev-worker-{}-{}".format(user_name, uuid.uuid1())
    update_stack_name = True
else:
    update_stack_name = False

# Check USE_SPOT_INSTANCE is a boolean
if not app.node.try_get_context("USE_SPOT_INSTANCE").lower() in ['true', 'false']:
    print("Error, USE_SPOT_INSTANCE context value must be boolean")
    print("Please use -c \"USE_SPOT_INSTANCE=true\" or -c \"USE_SPOT_INSTANCE=false\"")
    sys.exit(1)

dev_stack = DevWorkerStack(app, stack_name, env={"account": ACCOUNT, "region": REGION})

# Add tags to app
for key, value in TAGS.items():
    core.Tag.add(app, key, value)

app.synth()

if update_stack_name:
    # Set the stack name in the context
    # Read in
    with open('cdk.json', 'r') as cdk_fh:
        cdk_context = json.load(cdk_fh)
    # Update
    cdk_context['context']["STACK_NAME"] = stack_name
    # Write
    with open("cdk.json", 'w') as cdk_fh:
        cdk_fh.write(json.dumps(cdk_context, indent=2))
        cdk_fh.write("\n")

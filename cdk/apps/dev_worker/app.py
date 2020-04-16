#!/usr/bin/env python3

import sys
import os
import uuid
import json
from pathlib import Path

from aws_cdk import core

from dev_worker.dev_worker_stack import DevWorkerStack

# Set account vars
ACCOUNT = "843407916570"  # Dev
REGION = "ap-southeast-2"

# Set tags for container
TAGS = {
    "Stack": "DEV-CDK",
    "UseCase": "Testing-CDK",
    "Environment": "dev"
}

app = core.App()

# Check required args are not none
stack_name = app.node.try_get_context("STACK_NAME")

# Check Stack file
stack_file = Path(__file__).parent.absolute() / ".stack_name"

# Get user - used for stack_name and the creator tag
user_name = os.environ.get('USER')

# Check stack name
if stack_name is None:
    if stack_file.is_file():
        with open(stack_file, 'r') as stack_fh:
            # Should just be the first line
            stack_name = stack_fh.readline().strip()
    # Check there is a user
    elif not user_name:
        print("Error: no STACK_NAME defined!")
        print("Please use -c \"STACK_NAME=name-of-stack\" or set the $USER env variable.")
        sys.exit(1)
    else:
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

# Set creator tag
if not app.node.try_get_context("CREATOR"):
    creator_name = user_name
else:
    creator_name = app.node.try_get_context("CREATOR")

TAGS["Creator"] = creator_name

# Build the dev stack
dev_stack = DevWorkerStack(app, stack_name, env={"account": ACCOUNT, "region": REGION})

# Add tags to app
for key, value in TAGS.items():
    core.Tag.add(app, key, value)

app.synth()

if update_stack_name:
    # Set the stack name in the context
    # Read in
    with open(stack_file, 'w') as stack_fh:
        stack_fh.write(stack_name)
        stack_fh.write("\n")
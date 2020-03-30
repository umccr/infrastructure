#!/usr/bin/env python3

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
    "Creator": "Alexis Lucattini",
    "Environment": "dev"
}


app = core.App()

# Check required args are not none
stack_name = app.node.try_get_context("STACK_NAME")
key_name = app.node.try_get_context("KEY_NAME")

if stack_name is None:
    print("Error: STACK_NAME in cdk.json is not defined")
if key_name is None:
    print("Error: KEY_NAME in cdk.json is not defined")

DevWorkerStack(app, stack_name, env={"account": ACCOUNT, "region": REGION})

# Add tags to app
for key, value in TAGS.items():
    core.Tag.add(app, key, value)

app.synth()

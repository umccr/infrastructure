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
DevWorkerStack(app, "dev-worker", env={"account": ACCOUNT, "region": REGION})

# Add tags to app
for key, value in TAGS.items():
    core.Tag.add(app, key, value)

app.synth()

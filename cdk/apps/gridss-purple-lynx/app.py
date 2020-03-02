#!/usr/bin/env python3

from aws_cdk import core

from gridss_purple_lynx.gridss_purple_lynx_stack import GridssPurpleLynxStack

# Set account vars
ACCOUNT = "843407916570"  # Dev
REGION = "ap-southeast-2"
CREATOR_NAME = "Alexis Lucattini"

# Set tags for container
TAGS = {
    # Name is set to gridss-purple-lynx
    "Stack": "CDK",
    "UseCase": "Testing-CDK",
    "Creator": "Alexis Lucattini",
    "Environment": "dev"
}

# Set other globals

# Initialise app
app = core.App()

# Build stack on app
GridssPurpleLynxStack(app, "gridss-purple-lynx", env={"account": ACCOUNT, "region": REGION})

# Add tags to app
for key, value in TAGS.items():
    core.Tag.add(app, key, value)

app.synth()

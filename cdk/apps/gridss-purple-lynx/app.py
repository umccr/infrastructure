#!/usr/bin/env python3

from aws_cdk import core

from gridss_purple_lynx.gridss_purple_lynx_stack import GridssPurpleLynxStack

# Set account vars
ACCOUNT = "843407916570"  # Dev
REGION = "ap-southeast-2"

app = core.App()
GridssPurpleLynxStack(app, "gridss-purple-lynx", env={"account": ACCOUNT, "region": REGION})

app.synth()

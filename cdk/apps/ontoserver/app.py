#!/usr/bin/env python3
import os

from aws_cdk import core

from ontoserver_stack import OntoserverStack

account_id = os.environ.get("CDK_DEFAULT_ACCOUNT")
aws_region = os.environ.get("CDK_DEFAULT_REGION")
aws_env = {"account": account_id, "region": aws_region}

# we use this string as a way of labelling artifacts.. i.e. stack ids, descriptions in security groups etc
UNIQUE_NAMESPACE = "Ontoserver"

app = core.App()

OntoserverStack(
    app,
    UNIQUE_NAMESPACE,
    stack_name=UNIQUE_NAMESPACE.lower(),
    # the name of the docker repository (in the same as the deployed account) - FIX??
    ontoserver_repo_name="ontoserver-umccr",
    # the tag of the image
    ontoserver_tag="latest",
    # the dns prefix that is used for the ALB .. i.e. <dns_record_name>.dev.umccr.org
    dns_record_name="onto",
    env=aws_env,
    tags={
        "Stack": UNIQUE_NAMESPACE,
        "Creator": "cdk",
        "Environment": account_id,
    }
)

app.synth()

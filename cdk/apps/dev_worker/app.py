#!/usr/bin/env python3

from aws_cdk import core

from dev_worker.dev_worker_stack import DevWorkerStack


app = core.App()
DevWorkerStack(app, "dev-worker")

app.synth()

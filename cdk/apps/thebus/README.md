# UMCCR's Event Bus system

This is an attempt to overhaul a multiple-queues system with a unified event Bus, leveraging EventBridge instead of maintaining a web of individual SQS/SNS components.

[CDKv2 (beta)][cdkv2-beta] is used here. Also, the recent integration of [SAM and CDK][sam-cdk].

## Quickstart

```
# Pre-requisites:
pip install -r requirements.txt       # pulls in CDKv2 `aws-cdk-lib` and `construct` libs
npm install -g aws-cdk@2.0.0-rc.4
brew reinstall aws-sam-cli-beta-cdk

# Running and deploying:
make build
make run	# As in running lambdas locally
make deploy
```

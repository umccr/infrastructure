# UMCCR's Event Bus system

This is an attempt to overhaul a multiple-queues system with a unified event Bus, leveraging EventBridge instead of maintaining a web of individual SQS/SNS components.

[CDKv2 (beta)][cdkv2-beta] is used here. Also, the recent integration of [SAM and CDK][sam-cdk].

## Quickstart

```
pip install -r requirements.txt       # pulls in CDKv2 `aws-cdk-lib` and `construct` libs
npm install -g aws-cdk@2
brew reinstall aws-sam-cli-beta-cdk
```

# PoC TODO

* [x] Scope of the PoC (design): retroactively process reports via EventBridge to ingest them on data portal
* [x] Working `cdk synth` v1
* [x] Migrate to `CDKv2` 
* [x] Integrate with [SAM-CDK-BETA][sam-cdk]
* [ ] Connect and consume Illumina GDS events (**under develop workgroup**) to EventBridge.

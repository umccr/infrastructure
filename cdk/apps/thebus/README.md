# UMCCR's Bus system

This is an attempt to overhaul a multiple-queues system with a unified event Bus, leveraging EventBridge.

[CDKv2 (beta)][cdkv2-beta] is used here. Also, the recent integration of [SAM and CDK][sam-cdk].

# PoC TODO

[x] Scope of the PoC (design): retroactively process reports via EventBridge to ingest them on data portal
[x] Working `cdk synth` v1
[x] Migrate to `CDKv2` 
[ ] Integrate with [SAM][sam-cdk]
[ ] Write reports ingestion lambda.

[cdkv2-beta]: https://aws.amazon.com/blogs/developer/announcing-aws-cloud-development-kit-v2-developer-preview/
[sam-cdk]: https://aws.amazon.com/blogs/compute/better-together-aws-sam-and-aws-cdk/

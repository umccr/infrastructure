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
* [ ] Integrate with [SAM-CDK-BETA][sam-cdk]
* [ ] Connect and consume Illumina GDS events (**under develop workgroup**) to EventBridge.

# Current status/error/stage

```
% sam-beta-cdk local invoke TheBusStack/reports_ingestor
Synthesizing CDK App
Traceback (most recent call last):
  File "/opt/homebrew/bin/sam-beta-cdk", line 8, in <module>
    sys.exit(cli())
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/click/core.py", line 829, in __call__
    return self.main(*args, **kwargs)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/click/core.py", line 782, in main
    rv = self.invoke(ctx)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/click/core.py", line 1259, in invoke
    return _process_result(sub_ctx.command.invoke(sub_ctx))
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/click/core.py", line 1259, in invoke
    return _process_result(sub_ctx.command.invoke(sub_ctx))
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/click/core.py", line 1066, in invoke
    return ctx.invoke(self.callback, **ctx.params)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/click/core.py", line 610, in invoke
    return callback(*args, **kwargs)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/click/decorators.py", line 73, in new_func
    return ctx.invoke(f, obj, *args, **kwargs)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/click/core.py", line 610, in invoke
    return callback(*args, **kwargs)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/samcli/lib/telemetry/metric.py", line 174, in wrapped
    raise exception  # pylint: disable=raising-bad-type
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/samcli/lib/telemetry/metric.py", line 141, in wrapped
    return_value = func(*args, **kwargs)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/samcli/lib/iac/utils/helpers.py", line 30, in wrapper
    project = iac_plugin.get_project(lookup_paths)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/samcli/lib/iac/cdk/plugin.py", line 116, in get_project
    project = self._get_project_from_cloud_assembly(cloud_assembly_dir)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/samcli/lib/iac/cdk/plugin.py", line 207, in _get_project_from_cloud_assembly
    stacks: List[Stack] = [self._build_stack(cloud_assembly, ca_stack) for ca_stack in cloud_assembly.stacks]
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/samcli/lib/iac/cdk/plugin.py", line 207, in <listcomp>
    stacks: List[Stack] = [self._build_stack(cloud_assembly, ca_stack) for ca_stack in cloud_assembly.stacks]
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/samcli/lib/iac/cdk/plugin.py", line 222, in _build_stack
    self._build_resources_section(assets, ca_stack, cloud_assembly, section, section_dict)
  File "/opt/homebrew/Cellar/aws-sam-cli-beta-cdk/202104291816/libexec/lib/python3.8/site-packages/samcli/lib/iac/cdk/plugin.py", line 280, in _build_resources_section
    asset = assets[asset_path]
KeyError: '/Users/rvalls/dev/umccr/infrastructure/cdk/apps/thebus/lambdas'
```

[cdkv2-beta]: https://aws.amazon.com/blogs/developer/announcing-aws-cloud-development-kit-v2-developer-preview/
[sam-cdk]: https://aws.amazon.com/blogs/compute/better-together-aws-sam-and-aws-cdk/
[sam-cdk-local-serverless]: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-cdk-testing.html
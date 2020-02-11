#!/usr/bin/env python3
from aws_cdk import core
from stacks.orchestrator import OrchestratorStack

echo_tes_dev_props = {
    'namespace': 'showcase-iap-tes-dev',
    'iap_api_base_url': 'aps2.platform.illumina.com',
    'task_id': 'tdn.d4425331e3ba4779adafbf31176f0580',
    'task_version': 'tvn.b4735419fbe4455eb2b91960e48921f9',
    'ssm_param_name': '/iap/jwt-token',
    'ssm_param_version': 1,
    'image_name': 'ubuntu',
    'image_tag': 'latest',
    'gds_log_folder': 'gds://teslogs/ShowCase/'
}


app = core.App()

OrchestratorStack(
    app,
    echo_tes_dev_props['namespace'],
    echo_tes_dev_props,
    env={'account': '843407916570', 'region': 'ap-southeast-2'}
)

app.synth()

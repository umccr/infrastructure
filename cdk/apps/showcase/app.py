#!/usr/bin/env python3
from aws_cdk import core
from stacks.echo_tes import EchoTesStack

echo_tes_dev_props = {
    'namespace': 'echo-iap-tes-dev',
    'iap_api_base_url': 'aps2.platform.illumina.com',
    'task_id': 'tdn.08d5b213e9d74c6b9996d37fcf18f5b0',
    'task_version': 'tvn.fbfcd1166bfb4384a672ceeb786ebbe6',
    'ssm_param_name': '/iap/jwt-token',
    'ssm_param_version': 1,
    'image_name': 'umccr/rnasum',
    'image_tag': '0.3'
}


app = core.App()

EchoTesStack(
    app,
    echo_tes_dev_props['namespace'],
    echo_tes_dev_props,
    env={'account': '843407916570', 'region': 'ap-southeast-2'}
)

app.synth()

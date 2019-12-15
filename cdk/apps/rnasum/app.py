#!/usr/bin/env python3
from aws_cdk import core
from stacks.iap_tes import IapTesStack


iap_tes_dev_props = {
    'namespace': 'rnasum-iap-tes-dev',
    'iap_api_base_url': 'aps2.platform.illumina.com',
    'task_id': 'tdn.08d5b213e9d74c6b9996d37fcf18f5b0',
    'task_version_wts': 'tvn.fbfcd1166bfb4384a672ceeb786ebbe6',
    'task_version_wgs': 'tvn.513e48a9adb64d77addcdc3e5b468ef8',
    'ssm_param_name': '/iap/jwt-token',
    'ssm_param_version': 1,
    'rnasum_image_name': 'umccr/rnasum',
    'rnasum_image_tag': '0.2.9',
    'gds_refdata_folder': 'gds://umccr-refdata-dev/RNAsum/',
    'gds_log_folder': 'gds://teslogs/RNAsum/',
    'ref_data_name': 'PANCAN'
}

app = core.App()

IapTesStack(
    app,
    iap_tes_dev_props['namespace'],
    iap_tes_dev_props,
    env={'account': '843407916570', 'region': 'ap-southeast-2'}
)

app.synth()

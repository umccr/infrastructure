#!/usr/bin/env python3
from aws_cdk import core
from stacks.iap_tes import IapTesStack
from stacks.cicd import CICDStack
from stacks.batch import BatchStack
from stacks.common import CommonStack

rnasum_image = 'umccr/rnasum:0.3.5'

dev_env = {'account': '843407916570', 'region': 'ap-southeast-2'}
codebuild_project_name = 'rnasum_codebuild_project'
rnasum_ecr_repo = 'rnasum'

common_dev_props = {
    'namespace': 'rnasum-common-dev',
    'rnasum_ecr_repo': rnasum_ecr_repo,
    'vpc_id': 'vpc-0c459c431bac7d497'       # reuse umccrise common vpc for now
}

cicd_dev_props = {
    'namespace': 'rnasum-cicd',
    'codebuild_project_name': codebuild_project_name
}

batch_dev_props = {
    'namespace': 'rnasum-batch-dev',
    'container_image': rnasum_image,
    'compute_env_ami': 'ami-029bf83e14803c25f',  # Amazon ECS optimised Linux 2 AMI
    'compute_env_type': 'SPOT',
    'ro_buckets': ['umccr-refdata-prod', 'umccr-primary-data-prod', 'umccr-temp', 'umccr-refdata-dev'],
    'rw_buckets': ['umccr-primary-data-dev2', 'umccr-misc-temp'],
    'refdata_bucket': 'umccr-refdata-prod',
    'data_bucket': 'umccr-primary-data-prod'
}

iap_tes_dev_props = {
    'namespace': 'rnasum-iap-tes-dev',
    'iap_api_base_url': 'aps2.platform.illumina.com',
    'task_id': 'tdn.08d5b213e9d74c6b9996d37fcf18f5b0',
    'task_version_wts': 'tvn.fbfcd1166bfb4384a672ceeb786ebbe6',
    'task_version_wgs': 'tvn.513e48a9adb64d77addcdc3e5b468ef8',
    'ssm_param_name': '/iap/jwt-token',
    'ssm_param_version': 1,
    'rnasum_image_name': 'umccr/rnasum',
    'rnasum_image_tag': '0.3',
    'gds_refdata_folder': 'gds://umccr-refdata-dev/RNAsum/data/',
    'gds_log_folder': 'gds://teslogs/RNAsum/',
    'ref_data_name': 'PANCAN'
}

app = core.App()

common = CommonStack(
    app,
    common_dev_props['namespace'],
    common_dev_props,
    env=dev_env
)

IapTesStack(
    app,
    iap_tes_dev_props['namespace'],
    iap_tes_dev_props,
    env=dev_env
)

CICDStack(
    app,
    cicd_dev_props['namespace'],
    cicd_dev_props,
    env=dev_env
)

batch_dev_props['vpc'] = common.vpc
BatchStack(
    app,
    batch_dev_props['namespace'],
    batch_dev_props,
    env=dev_env
)

app.synth()

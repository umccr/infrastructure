#!/usr/bin/env python3
from aws_cdk import core
from stacks.cicd import CICDStack, CommonStack
from stacks.batch import BatchStack
from stacks.iap_tes import IapTesStack

dev_env = {'account': '843407916570', 'region': 'ap-southeast-2'}
prod_env = {'account': '472057503814', 'region': 'ap-southeast-2'}
umccrise_ecr_repo = 'umccrise'

common_dev_props = {
    'namespace': 'umccrise-common-dev',
    'umccrise_ecr_repo': umccrise_ecr_repo,
}

cicd_dev_props = {
    'namespace': 'umccrise-cicd'
}
batch_dev_props = {
    'namespace': 'umccrise-batch-dev',
    'container_image': 'umccr/umccrise:0.15.15',
    # 'compute_env_ami': 'ami-0e3451906ffc529a0',  # umccrise AMI
    'compute_env_ami': 'ami-05c621ca32de56e7a',  # Amazon ECS optimised Linux 2 AMI
    'compute_env_type': 'SPOT',
    'ro_buckets': ['umccr-refdata-prod', 'umccr-primary-data-prod', 'umccr-temp', 'umccr-refdata-dev'],
    'rw_buckets': ['umccr-primary-data-dev2', 'umccr-misc-temp'],
    'refdata_bucket': 'umccr-refdata-prod',
    'data_bucket': 'umccr-primary-data-prod'
}

batch_prod_props = {
    'namespace': 'umccrise-batch-prod',
    'container_image': 'umccr/umccrise:0.15.15',
    'compute_env_ami': 'ami-09975fb45a9e256c3',
    'compute_env_type': 'EC2',
    'ro_buckets': ['umccr-refdata-prod'],
    'rw_buckets': ['umccr-primary-data-prod', 'umccr-temp'],
    'refdata_bucket': 'umccr-refdata-prod',
    'data_bucket': 'umccr-primary-data-prod'
}

iap_tes_dev_props = {
    'namespace': 'umccrise-iap-tes-dev',
    'iap_api_base_url': 'aps2.platform.illumina.com',
    'task_id': 'tdn.3c6ef303643245bfa39542c7493ee0ea',
    'task_version_id': 'tvn.8ba13f1312144a8682020ae71a4ab9ce',
    'ssm_param_name': '/iap/jwt-token',
    'ssm_param_version': 1,
    'gds_refdata_folder': 'gds://genomes/umccrise2/',
    'gds_output_folder': 'gds://romanvg/umccrise/output',
    'gds_log_folder': 'gds://romanvg/logs',
    'umccrise_image_name': '843407916570.dkr.ecr.ap-southeast-2.amazonaws.com/umccr',
    'umccrise_image_tag': 'NOTAG-2a64459695'
}

app = core.App()
# NOTE: Don't rename stacks! CF can't track changes if the stack name changes.
# To rename a stack: delete, rename and deploy

# We don't want certain resources to get deleted when we destroy a stack, so
# we generate them in a separate common stack
# I.e. it would be unfortunate if a ECR repo would be deleted, just because
# the CI/CD stack was removed.
CommonStack(
    app,
    common_dev_props['namespace'],
    common_dev_props,
    env=dev_env
)
CICDStack(
    app,
    cicd_dev_props['namespace'],
    cicd_dev_props,
    env=dev_env
)
BatchStack(
    app,
    batch_dev_props['namespace'],
    batch_dev_props,
    env=dev_env
)
BatchStack(
    app,
    batch_prod_props['namespace'],
    batch_prod_props,
    env=prod_env
)
IapTesStack(
    app,
    iap_tes_dev_props['namespace'],
    iap_tes_dev_props,
    env=dev_env
)

app.synth()

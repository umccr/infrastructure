#!/usr/bin/env python3
import os
import boto3
from aws_cdk import core
from stacks.common import CommonStack
from stacks.cicd import CICDStack
from stacks.batch import BatchStack
from stacks.iap_tes import IapTesStack
from stacks.slack import CodeBuildLambdaStack

ssm_client = boto3.client('ssm')

# TODO: add error handling
# TODO: should those be stack specific, e.g. get a stack prefix?
ro_bucket_names = ssm_client.get_parameter(Name='/cdk/umccrise/batch/ro_buckets')['Parameter']['Value'].split(',')
rw_bucket_names = ssm_client.get_parameter(Name='/cdk/umccrise/batch/rw_buckets')['Parameter']['Value'].split(',')
container_image = ssm_client.get_parameter(Name='/cdk/umccrise/batch/default_container_image')['Parameter']['Value']
ec2_ami = ssm_client.get_parameter(Name='/cdk/umccrise/batch/ami')['Parameter']['Value']
compute_env_type = ssm_client.get_parameter(Name='/cdk/umccrise/batch/compute_env_type')['Parameter']['Value']
# TODO: the following are Lambda specific and could be loaded directly by the Lambda
# pro: cleaner infra code
# con: probably increases Lambda runtime slightly; not overwritable in Lambda env for quick testing
refdata_bucket = ssm_client.get_parameter(Name='/cdk/umccrise/batch/refdata_bucket')['Parameter']['Value']
input_bucket = ssm_client.get_parameter(Name='/cdk/umccrise/batch/input_bucket')['Parameter']['Value']
result_bucket = ssm_client.get_parameter(Name='/cdk/umccrise/batch/result_bucket')['Parameter']['Value']
image_configurable = ssm_client.get_parameter(Name='/cdk/umccrise/batch/image_configurable')['Parameter']['Value']

# TODO: Needs to be removed before going to prod
# Use CDK_DEFAULT_ACCOUNT and CDK_DEFAULT_REGION ?
account_id = os.environ.get('CDK_DEFAULT_ACCOUNT')
aws_region = os.environ.get('CDK_DEFAULT_REGION')
aws_env = {'account': account_id, 'region': aws_region}

umccrise_ecr_repo = 'umccrise'
codebuild_project_name = 'umccrise_codebuild_project'

common_dev_props = {
    'namespace': 'umccrise-common-dev',
    'umccrise_ecr_repo': umccrise_ecr_repo,
}

cicd_dev_props = {
    'namespace': 'umccrise-cicd',
    'codebuild_project_name': codebuild_project_name
}

batch_props = {
    'namespace': 'umccrise-batch',
    'container_image': container_image,
    'compute_env_ami': ec2_ami,  # Should be Amazon ECS optimised Linux 2 AMI
    'compute_env_type': compute_env_type,
    'ro_buckets': ro_bucket_names,
    'rw_buckets': rw_bucket_names,
    'refdata_bucket': refdata_bucket,
    'input_bucket': input_bucket,
    'result_bucket': result_bucket,
    'image_configurable': image_configurable
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

slack_dev_props = {
    'namespace': 'umccrise-codebuild-slack-dev',
    'slack_channel': '#arteria-dev',
    'codebuild_project_name': codebuild_project_name,
    'aws_account': aws_env['account']
}

app = core.App()
# NOTE: Don't rename stacks! CF can't track changes if the stack name changes.
# To rename a stack: delete, rename and deploy

# We don't want certain resources to get deleted when we destroy a stack, so
# we generate them in a separate common stack
# I.e. it would be unfortunate if a ECR repo would be deleted, just because
# the CI/CD stack was removed.
# TODO: Common infrasturcture should probably be under Terraform control
common = CommonStack(
    app,
    common_dev_props['namespace'],
    common_dev_props,
    env=aws_env
)
CICDStack(
    app,
    cicd_dev_props['namespace'],
    cicd_dev_props,
    env=aws_env
)
BatchStack(
    app,
    batch_props['namespace'],
    props=batch_props,
    env=aws_env
)
IapTesStack(
    app,
    iap_tes_dev_props['namespace'],
    iap_tes_dev_props,
    env=aws_env
)
slack_dev_props['ecr_name'] = common.ecr_name
CodeBuildLambdaStack(
    app,
    slack_dev_props['namespace'],
    slack_dev_props,
    env=aws_env
)
app.synth()

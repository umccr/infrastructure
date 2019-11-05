#!/usr/bin/env python3
from aws_cdk import core
from stacks.cicd import CICDStack
from stacks.batch import BatchStack


batch_dev_props = {
    'namespace': 'umccrise-batch-dev',
    'container_image': 'umccr/umccrise:0.15.15',
    'compute_env_ami': 'ami-0e3451906ffc529a0',
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


app = core.App()

CICDStack(
    app,
    "umccrise-cicd",
    env={'account': '843407916570', 'region': 'ap-southeast-2'}
)
BatchStack(
    app,
    batch_dev_props['namespace'],
    batch_dev_props,
    env={'account': '843407916570', 'region': 'ap-southeast-2'}
)
BatchStack(
    app,
    batch_prod_props['namespace'],
    batch_prod_props,
    env={'account': '472057503814', 'region': 'ap-southeast-2'}
)

app.synth()

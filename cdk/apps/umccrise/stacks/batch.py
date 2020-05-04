from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    aws_batch as batch,
    aws_s3 as s3,
    aws_ec2 as ec2,
    core
)

# User data script to run on Batch worker instance start up
# Main purpose: pull in umccrise wrapper script to execute in Batch job
# TODO: use variables (e.g. for device name)
user_data_script = """MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -euxo pipefail
echo START CUSTOM USERDATA
ls -al /opt/
mkdir /opt/container
curl --output /opt/container/umccrise-wrapper.sh https://raw.githubusercontent.com/umccr/workflows/master/umccrise/umccrise-wrapper.sh
ls -al /opt/container/
chmod 755 /opt/container/umccrise-wrapper.sh
ls -al /opt/container/
echo Listing disk devices
lsblk
echo formatting and mounting disk
# assuming the device is available under the requested name
sudo mkfs -t xfs /dev/xvdf
mount /dev/xvdf /mnt
docker info
echo END CUSTOM USERDATA
--==MYBOUNDARY==--"""


class BatchStack(core.Stack):
    # Loosely based on https://msimpson.co.nz/BatchSpot/

    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        ################################################################################
        # Set up permissions
        ro_buckets = set()
        for bucket in props['ro_buckets']:
            tmp_bucket = s3.Bucket.from_bucket_name(
                self,
                bucket,
                bucket_name=bucket
            )
            ro_buckets.add(tmp_bucket)

        rw_buckets = set()
        for bucket in props['rw_buckets']:
            tmp_bucket = s3.Bucket.from_bucket_name(
                self,
                bucket,
                bucket_name=bucket
            )
            rw_buckets.add(tmp_bucket)

        batch_service_role = iam.Role(
            self,
            'BatchServiceRole',
            assumed_by=iam.ServicePrincipal('batch.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSBatchServiceRole')
            ]
        )

        spotfleet_role = iam.Role(
            self,
            'AmazonEC2SpotFleetRole',
            assumed_by=iam.ServicePrincipal('spotfleet.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonEC2SpotFleetTaggingRole')
            ]
        )

        # Create role for Batch instances
        batch_instance_role = iam.Role(
            self,
            'BatchInstanceRole',
            role_name='UmccriseBatchInstanceRole',
            assumed_by=iam.CompositePrincipal(
                iam.ServicePrincipal('ec2.amazonaws.com'),
                iam.ServicePrincipal('ecs.amazonaws.com')
            ),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonEC2RoleforSSM'),
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonEC2ContainerServiceforEC2Role')
            ]
        )
        batch_instance_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "ec2:Describe*",
                    "ec2:AttachVolume",
                    "ec2:CreateVolume",
                    "ec2:CreateTags",
                    "ec2:ModifyInstanceAttribute"
                ],
                resources=["*"]
            )
        )
        batch_instance_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "ecs:ListClusters"
                ],
                resources=["*"]
            )
        )
        for bucket in ro_buckets:
            bucket.grant_read(batch_instance_role)
        for bucket in rw_buckets:
            bucket.grant_read_write(batch_instance_role)

        # Turn the instance role into a Instance Profile
        batch_instance_profile = iam.CfnInstanceProfile(
            self,
            'BatchInstanceProfile',
            instance_profile_name='UmccriseBatchInstanceProfile',
            roles=[batch_instance_role.role_name]
        )

        ################################################################################
        # Minimal networking
        vpc = props['vpc']

        ################################################################################
        # Setup Batch compute resources

        # Configure BlockDevice to expand instance disk space (if needed?)
        block_device_mappings = [
            {
                'deviceName': '/dev/xvdf',
                'ebs': {
                    'deleteOnTermination': True,
                    'volumeSize': 1024,
                    'volumeType': 'gp2'
                }
            }
        ]

        launch_template = ec2.CfnLaunchTemplate(
            self,
            'UmccriseBatchComputeLaunchTemplate',
            launch_template_name='UmccriseBatchComputeLaunchTemplate',
            launch_template_data={
                'userData': core.Fn.base64(user_data_script),
                'blockDeviceMappings': block_device_mappings
            }
        )

        launch_template_spec = batch.LaunchTemplateSpecification(
            launch_template_name=launch_template.launch_template_name,
            version='$Latest'
        )


        my_compute_res = batch.ComputeResources(
            type=batch.ComputeResourceType.SPOT,
            allocation_strategy=batch.AllocationStrategy.BEST_FIT_PROGRESSIVE,
            desiredv_cpus=0,
            maxv_cpus=128,
            minv_cpus=0,
            image=ec2.MachineImage.generic_linux(ami_map={'ap-southeast-2': props['compute_env_ami']}),
            launch_template=launch_template_spec,
            spot_fleet_role=spotfleet_role,
            instance_role=batch_instance_profile.instance_profile_name,
            vpc=vpc,
            #compute_resources_tags=core.Tag('Creator', 'Batch')
        )
        # XXX: How to add more than one tag above??
        # core.Tag.add(my_compute_res, 'Foo', 'Bar')

        my_compute_env = batch.ComputeEnvironment(
            self,
            'UmccriseBatchComputeEnv',
            compute_environment_name="UmccriseBatchComputeEnv",
            service_role=batch_service_role,
            compute_resources=my_compute_res
        )

        job_queue = batch.JobQueue(
            self,
            'UmccriseJobQueue',
            job_queue_name='umccrise_job_queue',
            compute_environments=[ batch.JobQueueComputeEnvironment(
                compute_environment=my_compute_env,
                order=1
            )],
            priority=10
        )

        ################################################################################
        # Set up job submission Lambda

        lambda_role = iam.Role(
            self,
            'UmccriseLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole'),
                iam.ManagedPolicy.from_aws_managed_policy_name('AWSBatchFullAccess')  # TODO: restrict!
            ]
        )

        for bucket in ro_buckets:
            bucket.grant_read(lambda_role)
        for bucket in rw_buckets:
            bucket.grant_read(lambda_role)

        lmbda.Function(
            self,
            'UmccriseLambda',
            function_name='umccrise_batch_lambda',
            handler='umccrise.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas/umccrise'),
            environment={
                'JOBNAME_PREFIX': "UMCCRISE_",
                'JOBQUEUE': job_queue.job_queue_name,
                'REFDATA_BUCKET': props['refdata_bucket'],
                'DATA_BUCKET': props['data_bucket'],
                'UMCCRISE_MEM': '50000',
                'UMCCRISE_VCPUS': '16'
            },
            role=lambda_role
        )

from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    aws_batch as batch,
    aws_s3 as s3,
    aws_ec2 as ec2,
    core
)


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
            role_name='RnasumBatchInstanceRole',
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
            # TODO: restirct write to paths with */rnasum/*
            bucket.grant_read_write(batch_instance_role)

        # Turn the instance role into a Instance Profile
        batch_instance_profile = iam.CfnInstanceProfile(
            self,
            'BatchInstanceProfile',
            instance_profile_name='RnasumBatchInstanceProfile',
            roles=[batch_instance_role.role_name]
        )

        ################################################################################
        # Minimal networking
        # TODO: import resource created with TF
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
            'RnasumBatchComputeLaunchTemplate',
            launch_template_name='RnasumBatchComputeLaunchTemplate',
            launch_template_data={
                # 'userData': core.Fn.base64(user_data_script),   FIXME may not need this for RNAsum case? see job_definition below
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
            maxv_cpus=80,
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
            'RnasumBatchComputeEnv',
            compute_environment_name="RnasumBatchComputeEnv",
            service_role=batch_service_role,
            compute_resources=my_compute_res
        )

        job_queue = batch.JobQueue(
            self,
            'RnasumJobQueue',
            job_queue_name='rnasum_job_queue',
            compute_environments=[ batch.JobQueueComputeEnvironment(
                compute_environment=my_compute_env,
                order=1
            )],
            priority=10
        )

        # it is equivalent of
        # https://github.com/umccr/infrastructure/blob/master/terraform/stacks/wts_report/jobs/wts_report.json
        default_container_props = {
            'image': props['container_image'],
            'vcpus': 2,
            'memory': 2048,
            'command': [
                '/opt/container/WTS-report-wrapper.sh',
                'Ref::vcpus'
            ],
            'volumes': [
                {
                    'host': {
                        'sourcePath': '/mnt'
                    },
                    'name': 'work'
                },
                {
                    'host': {
                        'sourcePath': '/opt/container'
                    },
                    'name': 'container'
                }
            ],
            'mountPoints': [
                {
                    'containerPath': '/work',
                    'readOnly': False,
                    'sourceVolume': 'work'
                },
                {
                    'containerPath': '/opt/container',
                    'readOnly': True,
                    'sourceVolume': 'container'
                }
            ],
            'readonlyRootFilesystem': False,
            'privileged': True,
            'ulimits': []
        }

        # and CDK equivalent of
        # https://github.com/umccr/infrastructure/blob/master/terraform/stacks/wts_report/main.tf#L113
        job_definition = batch.CfnJobDefinition(
            self,
            'RnasumJobDefinition',
            job_definition_name='rnasum_job_dev',
            type='container',
            container_properties=default_container_props,
            parameters={
                'vcpus': 1,
            }
        )

        ################################################################################
        # Set up job submission Lambda

        lambda_role = iam.Role(
            self,
            'RnasumLambdaRole',
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

        # TODO: support dev/prod split, i.e. image being configurable on dev, but fixed on prod
        #       may need a default JobDefinition to be set up
        # and CDK equivalent of
        # https://github.com/umccr/infrastructure/blob/master/terraform/stacks/wts_report/main.tf#L159
        lmbda.Function(
            self,
            'RnasumLambda',
            function_name='rnasum_batch_lambda',
            handler='trigger_wts_report.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas/'),
            environment={
                'JOBNAME_PREFIX': "rnasum_",
                'JOBQUEUE': job_queue.job_queue_name,
                'JOBDEF': job_definition.job_definition_name,
                'REFDATA_BUCKET': props['refdata_bucket'],
                'DATA_BUCKET': props['data_bucket'],
                'JOB_MEM': '32000',
                'JOB_VCPUS': '8',
                'REF_DATASET': 'PANCAN',
                'GENOME_BUILD': '38',
            },
            role=lambda_role
        )

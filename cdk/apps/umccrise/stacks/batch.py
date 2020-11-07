from aws_cdk import (
    aws_batch as batch,
    aws_ec2 as ec2,
    aws_ecr as ecr,
    aws_ecs as ecs,
    aws_iam as iam,
    aws_lambda as lmbda,
    aws_s3 as s3,
    aws_s3_assets as assets,
    core
)
import os.path


class BatchStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        dirname = os.path.dirname(__file__)

        ecr_repo = ecr.Repository.from_repository_name(
            self,
            'UmccriseEcrRepo',
            repository_name='umccrise'
        )

        ################################################################################
        # Set up permissions
        ro_buckets = list()
        for bucket in props['ro_buckets']:
            tmp_bucket = s3.Bucket.from_bucket_name(
                self,
                bucket,
                bucket_name=bucket
            )
            ro_buckets.append(tmp_bucket)

        rw_buckets = list()
        for bucket in props['rw_buckets']:
            tmp_bucket = s3.Bucket.from_bucket_name(
                self,
                bucket,
                bucket_name=bucket
            )
            rw_buckets.append(tmp_bucket)

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
            # restirct write to paths with */umccrise/*
            bucket.grant_read_write(batch_instance_role, '*/umccrised/*')

        # Turn the instance role into a Instance Profile
        batch_instance_profile = iam.CfnInstanceProfile(
            self,
            'BatchInstanceProfile',
            instance_profile_name='UmccriseBatchInstanceProfile',
            roles=[batch_instance_role.role_name]
        )

        ################################################################################
        # Network
        # (Import common infrastructure (maintained via TerraForm)

        # VPC
        vpc = ec2.Vpc.from_lookup(
            self,
            'UmccrMainVpc',
            tags={'Name': 'main-vpc', 'Stack': 'networking'}
        )

        batch_security_group = ec2.SecurityGroup(
            self,
            "BatchSecurityGroup",
            vpc=vpc,
            description="Allow all outbound, no inbound traffic"
        )
        ################################################################################
        # Setup Batch compute resources

        # Configure BlockDevice to expand instance disk space (if needed?)
        block_device_mappings = [
            {
                'deviceName': '/dev/xvdf',
                'ebs': {
                    'deleteOnTermination': True,
                    'encrypted': True,
                    'volumeSize': 2048,
                    'volumeType': 'gp2'
                }
            }
        ]

        ##### Set up custom user data to configure the Batch instances

        # Set up local assets/files to be uploaded to S3 (so they are available when UserData requires them)
        umccrise_wrapper_asset = assets.Asset(
            self,
            'UmccriseWrapperAsset',
            path=os.path.join(dirname, '..', 'assets', "umccrise-wrapper.sh")
        )
        umccrise_wrapper_asset.grant_read(batch_instance_role)

        user_data_asset = assets.Asset(
            self,
            'UserDataAsset',
            path=os.path.join(dirname, '..', 'assets', "batch-user-data.sh")
        )
        user_data_asset.grant_read(batch_instance_role)

        cw_agent_config_asset = assets.Asset(
            self,
            'CwAgentConfigAsset',
            path=os.path.join(dirname, '..', 'assets', "cw-agent-config-addon.json")
        )
        cw_agent_config_asset.grant_read(batch_instance_role)

        # Now create the actual UserData
        # I.e. download the batch-user-data asset and run it with required parameters
        user_data = ec2.UserData.for_linux()
        local_path = user_data.add_s3_download_command(
            bucket=user_data_asset.bucket,
            bucket_key=user_data_asset.s3_object_key
        )
        user_data.add_execute_file_command(
            file_path=local_path,
            arguments=f"s3://{umccrise_wrapper_asset.bucket.bucket_name}/{umccrise_wrapper_asset.s3_object_key} s3://{cw_agent_config_asset.bucket.bucket_name}/{cw_agent_config_asset.s3_object_key}"
        )

        # Generate user data wrapper to comply with LaunchTemplate required MIME multi-part archive format for user data
        mime_wrapper = ec2.UserData.custom('MIME-Version: 1.0')
        mime_wrapper.add_commands('Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="')
        mime_wrapper.add_commands('')
        mime_wrapper.add_commands('--==MYBOUNDARY==')
        mime_wrapper.add_commands('Content-Type: text/x-shellscript; charset="us-ascii"')
        mime_wrapper.add_commands('')
        # install AWS CLI, as it's unexpectedly missing from the AWS Linux 2 AMI...
        mime_wrapper.add_commands('yum -y install unzip')
        mime_wrapper.add_commands('cd /opt')
        mime_wrapper.add_commands('curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"')
        mime_wrapper.add_commands('unzip awscliv2.zip')
        mime_wrapper.add_commands('sudo ./aws/install --bin-dir /usr/bin')
        # insert our actual user data payload
        mime_wrapper.add_commands(user_data.render())
        mime_wrapper.add_commands('--==MYBOUNDARY==--')

        launch_template = ec2.CfnLaunchTemplate(
            self,
            'UmccriseBatchComputeLaunchTemplate',
            launch_template_name='UmccriseBatchComputeLaunchTemplate',
            launch_template_data={
                'userData': core.Fn.base64(mime_wrapper.render()),
                'blockDeviceMappings': block_device_mappings
            }
        )

        launch_template_spec = batch.LaunchTemplateSpecification(
            launch_template_name=launch_template.launch_template_name,
            version='$Latest'
        )

        my_compute_res = batch.ComputeResources(
            type=(batch.ComputeResourceType.SPOT if props['compute_env_type'].lower() == 'spot' else batch.ComputeResourceType.ON_DEMAND),
            allocation_strategy=batch.AllocationStrategy.BEST_FIT,
            desiredv_cpus=0,
            maxv_cpus=320,
            minv_cpus=0,
            image=ec2.MachineImage.generic_linux(ami_map={'ap-southeast-2': props['compute_env_ami']}),
            launch_template=launch_template_spec,
            spot_fleet_role=spotfleet_role,
            instance_role=batch_instance_profile.instance_profile_name,
            vpc=vpc,
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PRIVATE,
                # availability_zones=["ap-southeast-2a"]
            ),
            security_groups=[batch_security_group],
            compute_resources_tags={
                'Creator': 'Batch',
                'Stack': 'umccrise',
                'Name': 'BatchWorker'
                }
        )
        # XXX: How to add more than one tag above??
        # https://github.com/aws/aws-cdk/issues/7350
        # core.Tag.add(my_compute_res, 'Foo', 'Bar')

        my_compute_env = batch.ComputeEnvironment(
            self,
            'UmccriseBatchComputeEnv',
            compute_environment_name="cdk-umccr_ise-batch-compute-env",
            service_role=batch_service_role,
            compute_resources=my_compute_res
        )
        # child = my_compute_env.node.default_child
        # child_comp_res = child.compute_resources
        # child_comp_res.tags = "{'Foo': 'Bar'}"

        job_queue = batch.JobQueue(
            self,
            'UmccriseJobQueue',
            job_queue_name='cdk-umccrise_job_queue',
            compute_environments=[
                batch.JobQueueComputeEnvironment(
                    compute_environment=my_compute_env,
                    order=1
                )
            ],
            priority=10
        )

        job_container = batch.JobDefinitionContainer(
            image=ecs.ContainerImage.from_registry(name=props['container_image']),
            vcpus=32,
            memory_limit_mib=100000,
            command=[
                "/opt/container/umccrise-wrapper.sh",
                "Ref::vcpus"
            ],
            mount_points=[
                ecs.MountPoint(
                    container_path='/work',
                    read_only=False,
                    source_volume='work'
                ),
                ecs.MountPoint(
                    container_path='/opt/container',
                    read_only=True,
                    source_volume='container'
                )
            ],
            volumes=[
                ecs.Volume(
                    name='container',
                    host=ecs.Host(
                        source_path='/opt/container'
                    )
                ),
                ecs.Volume(
                    name='work',
                    host=ecs.Host(
                        source_path='/mnt'
                    )
                )
            ],
            privileged=True
        )

        job_definition = batch.JobDefinition(
            self,
            'UmccriseJobDefinition',
            job_definition_name='cdk-umccrise-job-definition',
            parameters={'vcpus': '1'},
            container=job_container,
            retry_attempts=2,
            timeout=core.Duration.hours(5)
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
        ecr_repo.grant(lambda_role, 'ecr:ListImages')

        # TODO: support dev/prod split, i.e. image being configurable on dev, but fixed on prod
        #       may need a default JobDefinition to be set up
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
                'UMCCRISE_MEM': '100000',
                'UMCCRISE_VCPUS': '32',
                'JOBDEF': job_definition.job_definition_name,
                'REFDATA_BUCKET': props['refdata_bucket'],
                'INPUT_BUCKET': props['input_bucket'],
                'RESULT_BUCKET': props['result_bucket'],
                'IMAGE_CONFIGURABLE': props['image_configurable']
            },
            role=lambda_role
        )

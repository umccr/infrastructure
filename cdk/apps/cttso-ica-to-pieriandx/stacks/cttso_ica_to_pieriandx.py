from aws_cdk import (
    Stack,
    aws_batch_alpha as batch,
    aws_ecr as ecr,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_iam as iam,
    aws_lambda,
    aws_s3_assets as assets,
    Fn,
    Duration
)
from constructs import Construct

from pathlib import Path
from typing import Dict


class CttsoIcaToPieriandxStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, props: Dict, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # The code that defines your stack goes here
        env = kwargs.get("env")

        # Set a prefix - rather than writing cttso-ica-to-pieriandx many times
        cdk_attribute_prefix = "ctTSOICAToPierianDx"

        # Add batch service role
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
            role_name=f'{cdk_attribute_prefix}BatchInstanceRole',
            assumed_by=iam.CompositePrincipal(
                iam.ServicePrincipal('ec2.amazonaws.com'),
                iam.ServicePrincipal('ecs.amazonaws.com')
            ),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonEC2RoleforSSM'),
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonEC2ContainerServiceforEC2Role'),
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonECSTaskExecutionRolePolicy'),
                iam.ManagedPolicy.from_aws_managed_policy_name('SecretsManagerReadWrite')
            ]
        )

        # Add list clusters ecs to policy
        # FIXME - don't know why I need to do this - mybe I don't
        # batch_instance_role.add_to_policy(
        #     iam.PolicyStatement(
        #         actions=[
        #             "ecs:ListClusters"
        #         ],
        #         resources=["*"]
        #     )
        # )

        # Turn the instance role into a Instance Profile
        batch_instance_profile = iam.CfnInstanceProfile(
            self,
            'BatchInstanceProfile',
            instance_profile_name=f'{cdk_attribute_prefix}BatchInstanceProfile',
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
        # block_device_mappings = [
        #     {
        #         'deviceName': '/dev/xvdf',
        #         'ebs': {
        #             'deleteOnTermination': True,
        #             'encrypted': True,
        #             'volumeSize': 2048,
        #             'volumeType': 'gp2'
        #         }
        #     }
        # ]

        # Now create the actual UserData
        # I.e. download the batch-user-data asset and run it with required parameters
        # Set up local assets/files to be uploaded to S3 (so they are available when UserData requires them)
        cttso_ica_to_pieriandx_wrapper_asset = assets.Asset(
            self,
            f'{cdk_attribute_prefix}WrapperAsset',
            path=str(
                Path(__file__).parent.joinpath(Path("../") / 'assets' / "cttso-ica-to-pieriandx-wrapper.sh").resolve())
        )
        cttso_ica_to_pieriandx_wrapper_asset.grant_read(batch_instance_role)

        #user_data_asset = assets.Asset(
        #    self,
        #    'UserDataAsset',
        #    path=str(Path(__file__).parent.joinpath(Path("../") / 'assets' / "batch-user-data.sh"))
        #)
        #user_data_asset.grant_read(batch_instance_role)

        cw_agent_config_asset = assets.Asset(
            self,
            f'{cdk_attribute_prefix}CwAgentConfigAsset',
            path=str(Path(__file__).parent.joinpath(Path("../") / 'assets' / "cw-agent-config-addon.json"))
        )
        cw_agent_config_asset.grant_read(batch_instance_role)

        # Set up resources
        # Add start of mime wrapper
        user_data_mappings = {
            "__S3_WRAPPER_SCRIPT_URL__": f"s3://{cttso_ica_to_pieriandx_wrapper_asset.bucket.bucket_name}/{cttso_ica_to_pieriandx_wrapper_asset.s3_object_key}",
            "__S3_CWA_CONFIG_URL__": f"s3://{cw_agent_config_asset.bucket.bucket_name}/{cw_agent_config_asset.s3_object_key}"
        }

        with open(str((Path(__file__).parent.joinpath(Path("../") / 'assets' / "batch-user-data.sh")).resolve()), 'r') as user_data_h:
            # Use a substitution
            user_data_sub = Fn.sub(user_data_h.read(), user_data_mappings)

        # Import substitution object into user_data set
        user_data = ec2.UserData.custom(user_data_sub)

        mime_wrapper = ec2.UserData.custom('MIME-Version: 1.0')
        #
        mime_wrapper.add_commands('Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="')
        mime_wrapper.add_commands('')
        mime_wrapper.add_commands('--==MYBOUNDARY==')
        mime_wrapper.add_commands('Content-Type: text/x-shellscript; charset="us-ascii"')
        #
        # # Get batch user data asset
        # with open(str(Path(__file__).parent.joinpath(Path("../") / "assets" / "batch-user-data.sh").resolve()), 'rb') as user_data_h:
        #     # Skip the first line (Shebang)
        #     _ = user_data_h.readline()
        #     # Read in user data
        #     mime_wrapper.add_commands(str(user_data_h.read(), 'utf-8'))
        #
        #
        #
        # Add user data to mime wrapper
        mime_wrapper.add_commands(user_data.render())
        #
        # Add ending to mime wrapper
        mime_wrapper.add_commands('--==MYBOUNDARY==--')

        # Launch template
        launch_template = ec2.LaunchTemplate(
            self,
            f'{cdk_attribute_prefix}BatchComputeLaunchTemplate',
            launch_template_name=f'{cdk_attribute_prefix}BatchComputeLaunchTemplate',
            user_data=mime_wrapper,
            block_devices=[
                ec2.BlockDevice(device_name='/dev/xvdf',
                                volume=ec2.BlockDeviceVolume.ebs(
                                    volume_size=64,  # GB
                                    volume_type=ec2.EbsDeviceVolumeType.GP2,
                                    encrypted=True,
                                    delete_on_termination=True)
                                )
            ]
        )

        # Add in user data, see https://github.com/aws/aws-cdk/issues/6427#issuecomment-595626666
        # launch_template.add_property_override(
        #     "LaunchTemplateData", {
        #         "UserData": Fn.base64(user_data.render())
        #     }
        # )

        # Launch template specs
        launch_template_spec = batch.LaunchTemplateSpecification(
            launch_template_name=f'{cdk_attribute_prefix}BatchComputeLaunchTemplate',
            version=launch_template.version_number
        )

        # Compute resources
        my_compute_res = batch.ComputeResources(
            type=batch.ComputeResourceType.ON_DEMAND,
            allocation_strategy=batch.AllocationStrategy.BEST_FIT,
            desiredv_cpus=0,
            maxv_cpus=32,
            minv_cpus=0,
            image=ec2.MachineImage.generic_linux(ami_map={'ap-southeast-2': props['compute_env_ami']}),
            launch_template=launch_template_spec,
            spot_fleet_role=spotfleet_role,
            instance_role=batch_instance_profile.instance_profile_name,
            vpc=vpc,
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PRIVATE_WITH_NAT,
                availability_zones=["ap-southeast-2a"]
            ),
            security_groups=[batch_security_group],
            compute_resources_tags={
                'Creator': 'Batch',
                'Stack': cdk_attribute_prefix,
                'Name': 'BatchWorker'
            }
        )

        my_compute_env = batch.ComputeEnvironment(
            self,
            f'{cdk_attribute_prefix}BatchComputeEnv',
            #  compute_environment_name=f"{cdk_attribute_prefix}-batch-compute-env",  # naming means unable to update
            service_role=batch_service_role,
            compute_resources=my_compute_res
        )
        # child = my_compute_env.node.default_child
        # child_comp_res = child.compute_resources
        # child_comp_res.tags = "{'Foo': 'Bar'}"

        job_queue = batch.JobQueue(
            self,
            f'{cdk_attribute_prefix}JobQueue',
            job_queue_name=f'cdk-{cdk_attribute_prefix}_job_queue',
            compute_environments=[
                batch.JobQueueComputeEnvironment(
                    compute_environment=my_compute_env,
                    order=1
                )
            ],
            priority=10
        )

        job_container = batch.JobDefinitionContainer(
            image=ecs.ContainerImage.from_ecr_repository(
                repository=ecr.Repository.from_repository_attributes(
                    self,
                    id="ECR",
                    repository_arn='arn:aws:ecr:{0}:{1}:{2}'.format(
                        env['region'], env['account'], props['image_name'].split(":")[0]),
                    repository_name=props['image_name'].split(":")[0]
                ),
                tag=props["image_name"].split(":", 1)[-1]),
            vcpus=1,
            user="cttso_ica_to_pieriandx_user:cttso_ica_to_pieriandx_group",
            memory_limit_mib=1024,
            command=[
                "/opt/container/cttso-ica-to-pieriandx-wrapper.sh",
                "--ica-workflow-run-id", "Ref::ica_workflow_run_id",
                "--accession-json-base64-str", "Ref::accession_json_base64_str",
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
        )

        job_definition = batch.JobDefinition(
            self,
            f'{cdk_attribute_prefix}JobDefinition',
            job_definition_name=f'cdk-{cdk_attribute_prefix}-job-definition',
            parameters={},
            container=job_container,
            retry_attempts=2,
            timeout=Duration.hours(5)
        )

        ################################################################################
        # Set up job submission Lambda
        lambda_role = iam.Role(
            self,
            f'{cdk_attribute_prefix}LambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole'),
                # TODO - too much!
                iam.ManagedPolicy.from_aws_managed_policy_name('AWSBatchFullAccess'),
                iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMReadOnlyAccess')
            ]
        )

        runtime = aws_lambda.Runtime(
            name="python3.9"
        )

        aws_lambda.Function(
            self,
            f'{cdk_attribute_prefix}Lambda',
            function_name=f'{cdk_attribute_prefix}_batch_lambda',
            handler='cttso_ica_to_pieriandx.lambda_handler',
            runtime=runtime,
            code=aws_lambda.Code.from_asset(str(Path(__file__).parent.joinpath(Path("../") / "lambdas" / "cttso_ica_to_pieriandx").resolve())),
            environment={
                'JOBDEF': job_definition.job_definition_name,
                'JOBQUEUE': job_queue.job_queue_name,
                'JOBNAME_PREFIX': "CTTSO_ICA_TO_PIERIANDX_",
                'MEM': '1000',
                'VCPUS': '1'
            },
            role=lambda_role
        )








from aws_cdk import (
    Stack,
    aws_batch as batch,
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
            role_name='ctTSOICAToPierianDxBatchInstanceRole',
            assumed_by=iam.CompositePrincipal(
                iam.ServicePrincipal('ec2.amazonaws.com'),
                iam.ServicePrincipal('ecs.amazonaws.com')
            ),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonEC2RoleforSSM'),
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonEC2ContainerServiceforEC2Role')
            ]
        )

        # Turn the instance role into a Instance Profile
        # FIXME - see if there's better CfnInstanceProfiles?
        batch_instance_profile = iam.CfnInstanceProfile(
            self,
            'BatchInstanceProfile',
            instance_profile_name='ctTSOICAToPierianDxBatchInstanceProfile',
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

        # Set up resources

        # Get batch user data asset
        with open("assets/batch-user-data.sh", 'r') as user_data_h:
            # Read in user data
            user_data = ec2.UserData.custom(user_data_h.read())

        # Now create the actual UserData
        # I.e. download the batch-user-data asset and run it with required parameters
        # Set up local assets/files to be uploaded to S3 (so they are available when UserData requires them)
        cttso_ica_to_pieriandx_wrapper_asset = assets.Asset(
            self,
            'cttsoicatopieriandxWrapperAsset',
            path=str(Path(__file__).parent.joinpath(Path("../") / 'assets' / "cttso-ica-to-pieriandx-wrapper.sh").resolve())
        )
        cttso_ica_to_pieriandx_wrapper_asset.grant_read(batch_instance_role)

        user_data_asset = assets.Asset(
            self,
            'UserDataAsset',
            path=str(Path(__file__).parent.joinpath(Path("../") / 'assets' / "batch-user-data.sh"))
        )
        user_data_asset.grant_read(batch_instance_role)

        cw_agent_config_asset = assets.Asset(
            self,
            'CwAgentConfigAsset',
            path=str(Path(__file__).parent.joinpath(Path("../") / 'assets' / "cw-agent-config-addon.json"))
        )
        cw_agent_config_asset.grant_read(batch_instance_role)

        # Get local path and add to user data
        local_path = user_data.add_s3_download_command(
            bucket=user_data_asset.bucket,
            bucket_key=user_data_asset.s3_object_key
        )
        user_data.add_execute_file_command(
            file_path=local_path,
            arguments=f"s3://{cttso_ica_to_pieriandx_wrapper_asset.bucket.bucket_name}/{cttso_ica_to_pieriandx_wrapper_asset.s3_object_key} "
                      f"s3://{cw_agent_config_asset.bucket.bucket_name}/{cw_agent_config_asset.s3_object_key}"
        )

        # Launch template
        launch_template = ec2.LaunchTemplate(
            self,
            'cttsoicatopieriandxBatchComputeLaunchTemplate',
            launch_template_name='cttsoicatopieriandxBatchComputeLaunchTemplate',
            launch_template_data={
                'userData': Fn.base64(user_data.render()),
                'blockDeviceMappings': block_device_mappings,
                'metadataOptions': {
                    'httpTokens': 'required'
                }
            }
        )

        # Launch template specs
        launch_template_spec = batch.LaunchTemplateSpecification(
            launch_template_name=launch_template.launch_template_name,
            version='$Latest'
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
                subnet_type=ec2.SubnetType.PRIVATE,
                availability_zones=["ap-southeast-2a"]
            ),
            security_groups=[batch_security_group],
            compute_resources_tags={
                'Creator': 'Batch',
                'Stack': 'cttso-ica-to-pieriandx',
                'Name': 'BatchWorker'
            }
        )

        my_compute_env = batch.ComputeEnvironment(
            self,
            'cttsoicatopieriandxBatchComputeEnv',
            compute_environment_name="cdk-cttsoicatopieriandx-batch-compute-env",
            service_role=batch_service_role,
            compute_resources=my_compute_res
        )
        # child = my_compute_env.node.default_child
        # child_comp_res = child.compute_resources
        # child_comp_res.tags = "{'Foo': 'Bar'}"

        job_queue = batch.JobQueue(
            self,
            'cttsoicatopieriandxJobQueue',
            job_queue_name='cdk-cttsoicatopieriandx_job_queue',
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
            'cttsoicatopieriandxJobDefinition',
            job_definition_name='cdk-cttsoicatopieriandx-job-definition',
            parameters={},
            container=job_container,
            retry_attempts=2,
            timeout=Duration.hours(5)
        )

        ################################################################################
        # Set up job submission Lambda

        lambda_role = iam.Role(
            self,
            'cttsoicatopieriandxLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole'),
                # TODO: restrict!
                iam.ManagedPolicy.from_aws_managed_policy_name('AWSBatchFullAccess')
            ]
        )

        aws_lambda.Function(
            self,
            'cttsoicatopieriandxLambda',
            function_name='cttso_ica_to_pieriandx_batch_lambda',
            handler='cttso_ica_to_pieriandx.lambda_handler',
            runtime=aws_lambda.Runtime.PYTHON_3_7,
            code=aws_lambda.Code.from_asset('lambdas/cttso_ica_to_pieriandx'),
            environment={
                'JOBDEF': job_definition.job_definition_name,
                'JOBQUEUE': job_queue.job_queue_name,
                'JOBNAME_PREFIX': "CTTSO_ICA_TO_PIERIANDX_",
                'MEM': '1000',
                'VCPUS': '1'
            },
            role=lambda_role
        )








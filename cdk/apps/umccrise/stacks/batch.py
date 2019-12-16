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

        batch_instance_role = iam.Role(
            self,
            'BatchInstanceRole',
            assumed_by=iam.CompositePrincipal(
                iam.ServicePrincipal('ec2.amazonaws.com'),
                iam.ServicePrincipal('ecs.amazonaws.com')
            )
        )
        for bucket in ro_buckets:
            bucket.grant_read(batch_instance_role)
        for bucket in rw_buckets:
            bucket.grant_read_write(batch_instance_role)

        # Turn the instance role into a Instance Profile
        iam.CfnInstanceProfile(
            self,
            'BatchInstanceProfile',
            roles=[batch_instance_role.role_name]
        )

        # TODO: roll out across all AZs? (Will require more subnets, NATs, ENIs, etc...)
        vpc = ec2.Vpc(
            self,
            'UmccrVpc',
            cidr="10.2.0.0/16",
            max_azs=1
        )

        # TODO: Replace with proper CDK construct once available
        # TODO: Uses public subnet and default security group
        # TODO: Define custom AMI for compute env instances
        batch_comp_env = batch.CfnComputeEnvironment(
            self,
            'UmccriseBatchComputeEnv',
            type='MANAGED',
            service_role=batch_service_role.role_arn,
            compute_resources={
                'type': props['compute_env_type'],
                'maxvCpus': 128,
                'minvCpus': 0,
                'desiredvCpus': 0,
                'imageId': props['compute_env_ami'],
                'spotIamFleetRole': spotfleet_role.role_arn,
                'instanceRole': batch_instance_role.role_name,
                'instanceTypes': ['optimal'],
                'subnets': [vpc.public_subnets[0].subnet_id],
                'securityGroupIds': [vpc.vpc_default_security_group]
            }
        )

        # TODO: Replace with proper CDK construct once available
        # TODO: job_queue_name could result in a clash, but is currently necessary
        #       as we need a reference for the ENV variables of the lambda
        #       Could/Should append a unique element/string.
        job_queue = batch.CfnJobQueue(
            self,
            'UmccriseJobQueue',
            compute_environment_order=[{
                'computeEnvironment': batch_comp_env.ref,
                'order': 1
            }],
            priority=10,
            job_queue_name='umccrise_job_queue'
        )

        # TODO: Replace with proper CDK construct once available
        # TODO: Same reference issue as with job queue name
        job_definition = batch.CfnJobDefinition(
            self,
            'UmccriseJobDefinition',
            type='container',
            container_properties={
                "image": props['container_image'],
                "vcpus": 2,
                "memory": 2048,
                "command": [
                    "/opt/container/umccrise-wrapper.sh",
                    "Ref::vcpus"
                ],
                "volumes": [
                    {
                        "host": {
                            "sourcePath": "/mnt"
                        },
                        "name": "work"
                    },
                    {
                        "host": {
                            "sourcePath": "/opt/container"
                        },
                        "name": "container"
                    }
                ],
                "mountPoints": [
                    {
                        "containerPath": "/work",
                        "readOnly": False,
                        "sourceVolume": "work"
                    },
                    {
                        "containerPath": "/opt/container",
                        "readOnly": True,
                        "sourceVolume": "container"
                    }
                ],
                "readonlyRootFilesystem": False,
                "privileged": True,
                "ulimits": []
            },
            job_definition_name='umccrise_job_definition'
        )

        lambda_role = iam.Role(
            self,
            'UmccriseLambdaRole',
            assumed_by=iam.ServicePrincipal('lambda.amazonaws.com'),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AWSLambdaBasicExecutionRole')
            ]
        )

        for bucket in ro_buckets:
            bucket.grant_read(lambda_role)
        for bucket in rw_buckets:
            bucket.grant_read(lambda_role)

        lmbda.Function(
            self,
            'UmccriseLambda',
            handler='umccrise.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas/umccrise'),
            environment={
                'JOBNAME_PREFIX': "UMCCRISE_",
                'JOBQUEUE': job_queue.job_queue_name,
                'JOBDEF': job_definition.job_definition_name,
                'REFDATA_BUCKET': props['refdata_bucket'],
                'DATA_BUCKET': props['data_bucket'],
                'UMCCRISE_MEM': '50000',
                'UMCCRISE_VCPUS': '16'
            },
            role=lambda_role
        )

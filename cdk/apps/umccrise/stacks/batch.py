from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    aws_batch as batch,
    aws_s3 as s3,
    aws_ec2 as ec2,
    core
)


class BatchStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        refdata_bucket = s3.Bucket.from_bucket_attributes(
            self,
            'reference_data',
            bucket_name='umccr-refdata-prod'
        )

        primary_data_bucket = s3.Bucket.from_bucket_attributes(
            self,
            'primary_data',
            bucket_name='umccr-primary-data-prod'
        )

        misc_bucket = s3.Bucket.from_bucket_attributes(
            self,
            'temp_data',
            bucket_name='umccr-temp'
        )

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
        refdata_bucket.grant_read(batch_instance_role)
        primary_data_bucket.grant_read_write(batch_instance_role)
        misc_bucket.grant_read_write(batch_instance_role)

        iam.CfnInstanceProfile(
            self,
            'BatchInstanceProfile',
            roles=[batch_instance_role.role_name]
        )

        vpc = ec2.Vpc(
            self,
            'UmccrVpc',
            cidr="10.2.0.0/16",
            max_azs=1
        )

        batch_comp_env = batch.CfnComputeEnvironment(
            self,
            'UmccriseBatchComputeEnv',
            type='MANAGED',
            service_role=batch_service_role.role_arn,
            compute_resources={
                'type': 'SPOT',
                'maxvCpus': 128,
                'minvCpus': 0,
                'desiredvCpus': 0,
                'spotIamFleetRole': spotfleet_role.role_arn,
                'instanceRole': batch_instance_role.role_name,
                'instanceTypes': ['optimal'],
                'subnets': [vpc.public_subnets[0].subnet_id],
                'securityGroupIds': [vpc.vpc_default_security_group]
            }
        )

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

        # TODO: batch job definition
        job_definition = batch.CfnJobDefinition(
            self,
            'UmccriseJobDefinition',
            type='container',
            container_properties={
                "image": "umccr/umccrise:0.15.15",
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
        primary_data_bucket.grant_read(lambda_role)
        misc_bucket.grant_read(lambda_role)

        function = lmbda.Function(
            self,
            'UmccriseLambda',
            handler='umccrise.lambda_handler',
            runtime=lmbda.Runtime.PYTHON_3_7,
            code=lmbda.Code.from_asset('lambdas/umccrise'),
            environment={
                'JOBNAME_PREFIX': "UMCCRISE_",
                'JOBQUEUE': job_queue.job_queue_name,
                'JOBDEF': job_definition.job_definition_name,
                'REFDATA_BUCKET': refdata_bucket.bucket_name,
                'DATA_BUCKET': primary_data_bucket.bucket_name,
                'UMCCRISE_MEM': '50000',
                'UMCCRISE_VCPUS': '16'
            },
            role=lambda_role
        )

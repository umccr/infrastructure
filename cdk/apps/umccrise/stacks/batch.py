from aws_cdk import (
    aws_lambda as lmbda,
    aws_iam as iam,
    aws_batch as batch,
    aws_s3 as s3,
    aws_ec2 as ec2,
    core
)

user_data_script = """MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
echo Hello

--==MYBOUNDARY==--"""

user_data_script4 = """
Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0

#!/bin/bash
/bin/echo "Hello World" >> /tmp/testfile.txt
--//
"""


user_data_script2 = 'MIME-Version: 1.0\nContent-Type: multipart/mixed; boundary="==MYBOUNDARY=="\n--==MYBOUNDARY==\nContent-Type: text/x-shellscript; charset="us-ascii"\n#!/bin/bash\necho Hello\necho ${foo}\n--==MYBOUNDARY==--\n'

user_data_script3 = [
    'MIME-Version: 1.0',
    'Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="',
    '--==MYBOUNDARY==',
    'Content-Type: text/x-shellscript; charset="us-ascii"',
    '#!/bin/bash',
    'echo Hello',
    '--==MYBOUNDARY==--"""'
]


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
        for bucket in ro_buckets:
            bucket.grant_read(batch_instance_role)
        for bucket in rw_buckets:
            bucket.grant_read_write(batch_instance_role)
        # TODO: check if other permissions are needed (compare to Terraform)

        # Turn the instance role into a Instance Profile
        batch_instance_profile = iam.CfnInstanceProfile(
            self,
            'BatchInstanceProfile',
            instance_profile_name='UmccriseBatchInstanceProfile',
            roles=[batch_instance_role.role_name]
        )

        # TODO: roll out across all AZs? (Will require more subnets, NATs, ENIs, etc...)
        vpc = ec2.Vpc(
            self,
            'UmccrVpc',
            cidr="10.2.0.0/16",
            max_azs=1
        )

        user_data = ec2.UserData.for_linux()
        user_data.add_commands(core.Fn.base64(user_data_script4))

        launch_template = ec2.CfnLaunchTemplate(
            self,
            'UmccriseBatchComputeLaunchTemplate',
            launch_template_name='UmccriseBatchComputeLaunchTemplate',
            launch_template_data={
                # 'userData': core.Fn.base64(user_data.render())
                # 'userData': 'ZWNobyBGT09PT08K'
                # 'userData': {
                #     "Fn::Base64": {
                #         "Fn::Join": [
                #             "",
                #             "#!/bin/bash\n",
                #             "echo 'doing stuff'\n"
                #         ]
                #     }
                # }
                # 'userData': {'Fn::Base64': 'echo Hello'}
                'userData': core.Fn.base64(user_data_script4)
                # 'userData': core.Fn.base64(core.Fn.sub(body=user_data_script2, variables={'foo': 'World'}))
                # 'userData': core.Fn.join(delimiter='\n', list_of_values=user_data_script3)
                # TODO: try core.Fn.join()
            }
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
                'launchTemplate': {
                    "launchTemplateName": launch_template.launch_template_name
                },
                'spotIamFleetRole': spotfleet_role.role_arn,
                'instanceRole': batch_instance_profile.instance_profile_name,
                'instanceTypes': ['optimal'],
                'subnets': [vpc.public_subnets[0].subnet_id],
                'securityGroupIds': [vpc.vpc_default_security_group],
                'tags': {'Creator': 'Batch'}
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

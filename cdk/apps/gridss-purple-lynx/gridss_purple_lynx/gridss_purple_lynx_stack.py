from aws_cdk import (
    # For the instance
    aws_ec2 as ec2,
    # For access to ecr and s3
    aws_iam as iam,
    # Aws cdk essentials
    core
)

"""
Globals
"""

# Import into an existing vpc
VPC_ID = "vpc-6ceacc0b"  # default
SECURITY_GROUP = "sg-00f2e54b0bc480afa"  # default
SUBNET = "subnet-d52e978d"

# Set the ec2 type
EC2_TYPE = "m4.4xlarge"  # 16 vCPU & 64 GB of memory

# Set your keyname
KEY_NAME = "alexis-dev"

# Image type
MACHINE_IMAGE = ec2.GenericLinuxImage({
    "ap-southeast-2": "ami-0dc96254d5535925f",  # Refer to an existing AMI type
})

# Set volume size
VOLUME_SIZE = 100  # Size of ebs volume instance is mounted on in Gb
VOLUME_MOUNT_POINT = "/dev/xvdh"  # This is then mounted as /mnt/xvdh

# Gridss parameters
GRIDSS_DOCKER_IMAGE_NAME = "gridss-purple-linx"
GRIDSS_DOCKER_IMAGE_TAG = "2.7.3"


# Class definition
class GridssPurpleLynxStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Set a vpc
        vpc = ec2.Vpc.from_lookup(self, "VPC", is_default=True)
        vpc_subnets = ec2.SubnetSelection()

        # Set access policies for the instance
        policies = [
                    # Read only access for all our s3 buckets
                    iam.ManagedPolicy.from_aws_managed_policy_name("AmazonS3ReadOnlyAccess"),
                    # Set the container registry policy so we can pull docker containers from our ECR repo
                    iam.ManagedPolicy.from_aws_managed_policy_name("AmazonEC2ContainerRegistryReadOnly"),
                    # Allow us login by the ssm manger
                    iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMManagedInstanceCore")
                    ]

        # Get role object with set policies
        role = iam.Role(self, "EC2Role",
                        assumed_by=iam.ServicePrincipal("ec2.amazonaws.com"),
                        managed_policies=policies)

        # Get volume - contains a block device volume and a block device
        ebs_vol = ec2.BlockDeviceVolume.ebs(volume_size=VOLUME_SIZE)
        # Place volume on a block device with a set mount point
        ebs_block_device = ec2.BlockDevice(device_name=VOLUME_MOUNT_POINT, volume=ebs_vol)

        # Run boot strap -
        """
        The code under userdata.sh completes the following steps
        1. Installs docker into ec2 instance
        2. Mounts our volume to /mnt/
        3. Pulls the gridss container from our ECR (Elastic container repository)
        4. Imports the user data
        """
        with open("user_data/user_data.sh", 'r') as user_data_h:
            user_data = ec2.UserData.custom(user_data_h.read())

        # Set instance type from ec2-type global variable
        instance_type = ec2.InstanceType(instance_type_identifier=EC2_TYPE)

        # The code that defines your stack goes here
        # We take all of the parameters we have and place this into the ec2 instance class
        host = ec2.Instance(self,
                            id="gridss-ec2-id",
                            instance_type=instance_type,
                            instance_name="gridss-ec2-instance",
                            machine_image=MACHINE_IMAGE,
                            vpc=vpc,
                            vpc_subnets=vpc_subnets,
                            key_name=KEY_NAME,
                            role=role,
                            user_data=user_data,
                            block_devices=[ebs_block_device]
                            )

        # Pull the gridss-purple-linx container image from the ECR
        host.add_user_data("su - \"ec2-user\" -c \"docker pull \\\"%s.dkr.ecr.%s.amazonaws.com/%s:%s\\\"\"" % (core.Aws.ACCOUNT_ID,
                                                                                                               core.Aws.REGION,
                                                                                                               GRIDSS_DOCKER_IMAGE_NAME,
                                                                                                               GRIDSS_DOCKER_IMAGE_TAG))

        # Return public IP address s.t we can ssh into it
        # Note that we may return an IP prior to the user_data shell script completing so not
        # all of our goodies may be here yet
        core.CfnOutput(self, "Output",
                       value=host.instance_id)

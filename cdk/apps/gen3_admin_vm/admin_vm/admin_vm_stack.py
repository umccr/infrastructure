from aws_cdk import (
    aws_ec2 as ec2,
    aws_iam as iam,
    core
)

EXT_DEV_NAME = '/dev/xvdf'


class VmLookup(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        machine_image = ec2.MachineImage.lookup(name="ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64*",
                                                owners=['099720109477'])

        core.CfnOutput(self, "Selected Ubuntu AMI", value=machine_image.get_image(self).image_id)


class AdminVmStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Set a vpc
        vpc = ec2.Vpc.from_lookup(self, "VPC", is_default=True)
        vpc_subnets = ec2.SubnetSelection()

        # Set access policies for the instance
        policies = [
            # Read only access for all our s3 buckets
            iam.ManagedPolicy.from_aws_managed_policy_name("AdministratorAccess"),
            # Allow us login by the ssm manger
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMManagedInstanceCore")
        ]

        # Get role object with set policies
        role = iam.Role(self, "EC2Role",
                        assumed_by=iam.ServicePrincipal("ec2.amazonaws.com"),
                        managed_policies=policies)

        # Get a root ebs volume with specified sizw (mount: /dev/sda1)
        ebs_root_vol = ec2.BlockDeviceVolume.ebs(volume_size=int(self.node.try_get_context("ROOT_VOLUME_SIZE")))
        ebs_root_block_device = ec2.BlockDevice(device_name="/dev/sda1", volume=ebs_root_vol)

        # Get volume - contains a block device volume and a block device
        ebs_extended_vol = ec2.BlockDeviceVolume.ebs(volume_size=int(self.node.try_get_context("EXTENDED_VOLUME_SIZE")))
        # Place volume on a block device with a set mount point
        ebs_extended_block_device = ec2.BlockDevice(device_name=EXT_DEV_NAME,
                                                    volume=ebs_extended_vol)

        # # Run boot strap - User Data
        mappings = {"__EXT_DEV_NAME__": EXT_DEV_NAME,
                    "__EXT_DEV_MOUNT__": '/mnt/gen3'}
        with open("user_data/user_data.sh", 'r') as user_data_h:
            user_data_sub = core.Fn.sub(user_data_h.read(), mappings)
        user_data = ec2.UserData.custom(user_data_sub)

        # Set instance type from ec2-type in context
        instance_type = ec2.InstanceType(instance_type_identifier=self.node.try_get_context("EC2_TYPE"))

        machine_image = ec2.GenericLinuxImage({
            self.region: self.node.try_get_context("MACHINE_IMAGE"),  # Refer to an existing AMI type
        })

        # The code that defines your stack goes here
        # We take all of the parameters we have and place this into the ec2 instance class
        # Except LaunchTemplate which is added as a property to the instance
        host = ec2.Instance(self,
                            id="Gen3AdminVm",
                            instance_type=instance_type,
                            instance_name=self.node.try_get_context("INSTANCE_NAME"),
                            machine_image=machine_image,
                            vpc=vpc,
                            vpc_subnets=vpc_subnets,
                            role=role,
                            user_data=user_data,
                            block_devices=[ebs_root_block_device, ebs_extended_block_device],
                            )

        # Return instance ID
        core.CfnOutput(self, "Output",
                       value=host.instance_id)

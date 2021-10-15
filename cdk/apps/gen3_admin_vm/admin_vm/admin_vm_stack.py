from aws_cdk import (
    aws_ec2 as ec2,
    aws_iam as iam,
    core
)


class VmLookup(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        machine_image = ec2.MachineImage.lookup(name="ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64*",
                                                owners=['099720109477'])

        core.CfnOutput(self, "Latest Ubuntu 20.02 AMI", value=machine_image.get_image(self).image_id)


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

        # Get a root ebs volume (we mount it on /dev/xvda1)
        ebs_root_vol = ec2.BlockDeviceVolume.ebs(volume_size=int(self.node.try_get_context("ROOT_VOLUME_SIZE")))
        ebs_root_block_device = ec2.BlockDevice(device_name="/dev/xvda1", volume=ebs_root_vol)

        # Get volume - contains a block device volume and a block device
        ebs_extended_vol = ec2.BlockDeviceVolume.ebs(volume_size=int(self.node.try_get_context("EXTENDED_VOLUME_SIZE")))
        # Place volume on a block device with a set mount point
        ebs_extended_block_device = ec2.BlockDevice(device_name="/dev/sdg",
                                                    volume=ebs_extended_vol)

        # # Run boot strap -
        # """
        # The code under userdata.sh completes the following steps
        # 1. Installs docker into ec2 instance
        # 2. Mounts our volume to /mnt/
        # 3. Log into docker
        # """
        # mappings = {"__ACCOUNT_ID__": str(self.account),
        #             "__REGION__": str(self.region)}
        #
        # with open("user_data/user_data.sh", 'r') as user_data_h:
        #     # Use a substitution
        #     user_data_sub = core.Fn.sub(user_data_h.read(), mappings)
        #
        # # Import substitution object into user_data set
        # user_data = ec2.UserData.custom(user_data_sub)

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
                            # user_data=user_data,
                            block_devices=[ebs_root_block_device, ebs_extended_block_device],
                            )

        # if self.node.try_get_context("USE_SPOT_INSTANCE").lower() == 'true':
        #     # Spot pricing via ec2 fleet
        #     spot_price = self.node.try_get_context("MAX_SPOT_PRICE")
        #     market_options = {"MarketType": "spot"}
        #     if spot_price is not None:
        #         spot_options = {"MaxPrice": spot_price}
        #         market_options["SpotOptions"] = spot_options
        #     launch_template_data = {"InstanceMarketOptions": market_options}
        #     launch_template = ec2.CfnLaunchTemplate(self, "LaunchTemplate")
        #     launch_template.add_property_override("LaunchTemplateData", launch_template_data)
        #
        #     host.instance.add_property_override("LaunchTemplate", {"LaunchTemplateId": launch_template.ref,
        #                                                            "Version": launch_template.attr_latest_version_number})

        # Return public IP address s.t we can ssh into it
        # Note that we may return an IP prior to the user_data shell script completing so not
        # all of our goodies may be here yet
        core.CfnOutput(self, "Output",
                       value=host.instance_id)

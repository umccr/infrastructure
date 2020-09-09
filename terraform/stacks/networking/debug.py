import os

from aws_cdk import (
    core,
    aws_ec2 as ec2,
)

# See https://docs.aws.amazon.com/cdk/latest/guide/environments.html
env_profile = core.Environment(
    account=os.environ.get('CDK_DEPLOY_ACCOUNT', os.environ['CDK_DEFAULT_ACCOUNT']),
    region=os.environ.get('CDK_DEPLOY_REGION', os.environ['CDK_DEFAULT_REGION'])
)


class DebugStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Using tags filter on networking stack to get main-vpc in given env context
        vpc_name = "main-vpc"
        vpc_tags = {
            'Stack': 'networking',
        }
        vpc = ec2.Vpc.from_lookup(self, "VPC", vpc_name=vpc_name, tags=vpc_tags)

        print(">>> ec2.SubnetSelection(subnets=vpc.private_subnets)")
        vpc_subnet_selection: ec2.SubnetSelection = ec2.SubnetSelection(subnets=vpc.private_subnets)
        for subnet in vpc_subnet_selection.subnets:
            print(subnet.subnet_id)

        print(">>> subnet_group_name='database'")
        vpc_db_subnets: ec2.SelectedSubnets = vpc.select_subnets(subnet_group_name="database")
        for subnet in vpc_db_subnets.subnets:
            print(subnet.subnet_id)

        print(">>> ec2.SubnetType.PRIVATE")
        vpc_private_subnets: ec2.SelectedSubnets = vpc.select_subnets(subnet_type=ec2.SubnetType.PRIVATE)
        for subnet in vpc_private_subnets.subnets:
            print(subnet.subnet_id)

        print(">>> vpc.private_subnets")
        for subnet in vpc.private_subnets:
            print(subnet.subnet_id)

        print(">>> vpc.public_subnets")
        for subnet in vpc.public_subnets:
            print(subnet.subnet_id)

        print(">>> vpc.isolated_subnets")
        for subnet in vpc.isolated_subnets:
            print(subnet.subnet_id)

        # At the mo, CDK only offer existing Security Group by ID lookup, see https://github.com/aws/aws-cdk/issues/4241
        # FIXME might be possible to use tag lookup when this PR in https://github.com/aws/aws-cdk/pull/5641
        main_vpc_sg_uom_id = "sg-0d8aab41e8bb973c3"  # bound to DEV
        uom_sg = ec2.SecurityGroup.from_security_group_id(self, "main-vpc-sg-uom", main_vpc_sg_uom_id, mutable=False)
        print(">>> uom_sg")
        assert uom_sg is not None, f"{main_vpc_sg_uom_id} is only avail in DEV account"
        print(f"\t{uom_sg.to_string()}")


class DebugApp(core.App):
    def __init__(self):
        super().__init__()
        DebugStack(self, "debug-stack", props={}, env=env_profile)


if __name__ == '__main__':
    DebugApp().synth()


# Usage:
#   aws sso login --profile=dev
#   cdk synth --app="python3 debug.py" --profile=dev
#   cdk context -j | jq

# Footnote:
# Wondering those wired subnets id print upon first time synth like the following?
"""
>>> ec2.SubnetSelection(subnets=vpc.private_subnets)
p-12345
p-67890
>>> subnet_group_name='database'
>>> ec2.SubnetType.PRIVATE
p-12345
p-67890
>>> vpc.private_subnets
p-12345
p-67890
>>> vpc.public_subnets
s-12345
s-67890
>>> vpc.isolated_subnets
"""
# See https://github.com/aws/aws-cdk/blob/v1.44.0/packages/@aws-cdk/aws-ec2/lib/vpc.ts#L1922
# If you missed that try `cdk context --clear` and synth again!
# :)

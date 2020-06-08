# Networking

- This stack prepare AWS VPC network topology required for app deployment.
- This stack leverages [HashiCorp official AWS provider](https://registry.terraform.io/providers/hashicorp/aws/) VPC module available at [terraform-aws-modules / vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/) in module registry.
- This [terraform-aws-modules / vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/) is comprehensive module for VPC purpose and, able to adapt many network topology needs as its grows.
- It can also (re)create Gruntworks style Three Subnet Tiers for application deployment purpose i.e. [vpc-app](https://github.com/umccr/gruntworks-io-module-vpc/tree/master/modules/vpc-app) module.

## Subnet Tiers

At the moment, this VPC defines three "tiers" of subnets:

- **Public** subnets: Resources in these subnets are directly addressable from the Internet. Only public-facing resources (typically just load balancers) should be put here.
- **Private** (Private/App) subnets: Resources in these subnets are NOT directly addressable from the Internet but they can make outbound connections to the Internet through a NAT Gateway. You can connect to the resources in this subnet only from resources within the VPC, so you should put your app servers here and allow the load balancers in the Public Subnet to route traffic to them.
- **Database** (Private/Persistence) subnets: Resources in these subnets are neither directly addressable from the Internet nor able to make outbound Internet connections. You can connect to the resources in this subnet only from within the VPC, so you should put your databases, cache servers, and other stateful resources here and allow your apps to talk to them.

## Usage

- Print output for VPC ID: `terraform output`

#### Terraform

- In your app terraform, you can use [data source: aws_vpc](https://www.terraform.io/docs/providers/aws/d/vpc.html) to query this VPC. Recommended to use tag filters on `Name`, `Stack` and `Environment` keys over VPC ID as example below.

- You may further filter subnet by its tier. Example for how to filter _Private_ subnets using tag: `Tier = "private"`

```hcl-terraform
data "aws_vpc" "main_vpc" {
  # Using tags filter on networking stack to get main-vpc
  tags = {
    Name        = "main-vpc"
    Stack       = "networking"
    Environment = terraform.workspace
  }
}

data "aws_subnet_ids" "private_subnets" {
  vpc_id = data.aws_vpc.main_vpc.id

  tags = {
    Tier = "private"
  }
}
```

#### CDK

- Similarly for CDK, you can use [`VpcLookupOptions`](https://docs.aws.amazon.com/cdk/api/latest/docs/@aws-cdk_aws-ec2.VpcLookupOptions.html) on tags property to get this Main VPC.

- Specifically for Python CDK, you can use [`ec2.Vpc.from_lookup`](https://docs.aws.amazon.com/cdk/api/latest/python/aws_cdk.aws_ec2/Vpc.html#aws_cdk.aws_ec2.Vpc.from_lookup) static method to build VPC object as following example.

- In your stack, say `common.py`:

```python
from aws_cdk import (
    core,
    aws_ec2 as ec2,
)

class CommonStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Using tags filter on networking stack to get main-vpc in given env context
        vpc_name = "main-vpc"
        vpc_tags = {
            'Stack': 'networking',
        }
        vpc = ec2.Vpc.from_lookup(self, "VPC", vpc_name=vpc_name, tags=vpc_tags)
        self._vpc = vpc

    @property
    def vpc(self):
        return self._vpc
```

- And somewhere in `app.py`:

```python
from aws_cdk import core
from stacks.batch import BatchStack
from stacks.common import CommonStack

app = core.App()

env_dev = core.Environment(account="123456789", region="ap-southeast-2")
common_props = {'namespace': 'common-stack'}
batch_app_props = {'namespace': 'batch-stack'}

common = CommonStack(
    app,
    common_props['namespace'],
    common_props,
    env=env_dev
)

batch_app_props['vpc'] = common.vpc
BatchStack(
    app,
    batch_app_props['namespace'],
    batch_app_props,
    env=env_dev
)

app.synth()
```

- Note that VPC lookup is [context aware](https://docs.aws.amazon.com/cdk/latest/guide/context.html) and, it will be cached in `cdk.context.json` or use `cdk context -j | jq` to observe the cached VPC value for given environment context.

## Workspaces

This stack uses workspaces! It is typically applied against the AWS `prod` and `dev` accounts and uses Terraform workspaces to distinguish between those accounts. 

```
aws sso login --profile=dev
export AWS_PROFILE=dev
terraform workspace select dev
terraform ...
```

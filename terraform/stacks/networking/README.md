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

- In your app terraform, you can use [data source: aws_vpc](https://www.terraform.io/docs/providers/aws/d/vpc.html) to query this VPC. Recommended to use tag filters on `Name`, `Stack` and `Environment` keys.
- You may further [data query filter subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet_ids) by its **Tier** tag. Example for how to filter _Private_ subnets using tag: `Tier = "private"`
- You may also [data query filter security group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) by its **Name** tag. Example for how to filter _uom_ security group using tag: `Name = "uom"`

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

data "aws_security_group" "main_vpc_sg_uom" {
  vpc_id = data.aws_vpc.main_vpc.id

  # allow outbound traffic and UoM only inbound to SSH
  tags = {
    Name = "ssh_from_uom"
  }
}

data "aws_security_group" "main_vpc_sg_outbound" {
  vpc_id = data.aws_vpc.main_vpc.id

  # allow outbound only traffic
  tags = {
    Name = "outbound_only"
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

- And somewhere in `batch.py`:

```python
from aws_cdk import (
    core,
    aws_ec2 as ec2,
    aws_batch as batch,
    aws_lambda as lmbda,
)

class BatchStack(core.Stack):
    def __init__(self, scope: core.Construct, id: str, props, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Using main-vpc from networking stack
        vpc: ec2.Vpc = props['vpc']
        vpc_subnets: ec2.SubnetSelection = ec2.SubnetSelection(subnets=vpc.private_subnets)
        
        # create batch resource in private subnet (which is by default anyway)
        batch_compute_res = batch.ComputeResources(
            type=batch.ComputeResourceType.SPOT,
            vpc=vpc,
            vpc_subnets=vpc_subnets,
            # skip other kwargs for brevity
        )
        ...
        
        # create lambda resource in private subnet (which is by default anyway)
        lmbda.Function(
            self,
            runtime=lmbda.Runtime.PYTHON_3_7,
            vpc=vpc,
            vpc_subnets=vpc_subnets,
            # skip other kwargs for brevity
        )
        ...
```

- And somewhere in `app.py`:

```python
import os
from aws_cdk import core
from stacks.batch import BatchStack
from stacks.common import CommonStack

app = core.App()

env_profile=core.Environment(
    account=os.environ.get('CDK_DEPLOY_ACCOUNT', os.environ['CDK_DEFAULT_ACCOUNT']),
    region=os.environ.get('CDK_DEPLOY_REGION', os.environ['CDK_DEFAULT_REGION'])
)

common = CommonStack(
    app,
    'common-stack',
    props={},
    env=env_profile
)

BatchStack(
    app,
    'batch-stack',
    props={'vpc': common.vpc},
    env=env_profile
)

app.synth()
```

- See [`debug.py`](debug.py) for all possible ways you can filter out different subnets tier in CDK app from this main vpc.

- Note that VPC lookup is CDK [context aware](https://docs.aws.amazon.com/cdk/latest/guide/context.html) and, it will be cached in `cdk.context.json` or use `cdk context -j | jq` to observe the cached VPC value for given environment context.

## Notes

#### Subnet Tagging

- For `aws-cdk:subnet-name` and `aws-cdk:subnet-type` tags, CDK follows AWS style tagging. See section 'Best Practices for Naming Tags and Resources' in [aws-tagging-best-practices.pdf](https://d1.awsstatic.com/whitepapers/aws-tagging-best-practices.pdf). And this is also by observation from a VPC stack deployed using CDK elsewhere.
- Since we use Terraform for VPC setup here, added these two tags for convenience for filtering subnets by subnet type in downstream CDK app.
- In "CDK" world, subnet type is generalised enum type defined at [CDK `SubnetType` interface](https://docs.aws.amazon.com/cdk/api/latest/docs/@aws-cdk_aws-ec2.SubnetType.html) construct. Under the hood, CDK implemented this subnet type using "tag" filter, anyway.
- In "AWS" world, there is no such thing as "subnet type"! But tag filter is all that matter for tier-ing subnets for specific business use case and what meaningful to the organization.
- Hence we have the following tag combinations!

#### Remove all rules under default SG 

- After applying this VPC, please use Console UI to purge all rules (both ingress and egress rules) under this Main VPC default Security Group (SG) for [AWS CIS Security compliance](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-cis.html) purpose.
- Default Security Group for this Main VPC is, therefore, effectively lockdown mode to prevent any accidental network security implication.

## Workspaces

Login to AWS.
```
aws sso login --profile=dev && export AWS_PROFILE=dev
```

This stack uses terraform workspaces.
```
terraform workspace list
  default
* dev
  prod
  stg
```

It is typically applied against the AWS `prod` and `dev` accounts and uses Terraform workspaces to distinguish between those accounts.

```
terraform workspace select dev
terraform plan
terraform apply
```

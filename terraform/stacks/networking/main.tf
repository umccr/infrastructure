terraform {
  required_version = ">= 1.5.7"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "networking/terraform.tfstate"
    region = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "5.21.0"
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "ap-southeast-2"
}

resource "aws_eip" "main_vpc_nat_gateway" {
  count = 1
  domain = "vpc"

  tags = {
    Name        = "main-vpc-nat-gateway-eip"
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

module "main_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "main-vpc"
  cidr = "10.2.0.0/16"

  azs              = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  public_subnets   = ["10.2.0.0/23",  "10.2.2.0/23",  "10.2.4.0/23"]
  private_subnets  = ["10.2.20.0/23", "10.2.22.0/23", "10.2.24.0/23"]
  database_subnets = ["10.2.40.0/23", "10.2.42.0/23", "10.2.44.0/23"]

  # Single NAT Gateway Scenario
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  reuse_nat_ips       = true
  external_nat_ip_ids = aws_eip.main_vpc_nat_gateway.*.id

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_nat_gateway_route      = false  # true to give internet access (egress only)
  create_database_internet_gateway_route = false  # true for ingress from internet (NOT RECOMMENDED FOR PRODUCTION)

  enable_dns_hostnames = true
  enable_dns_support   = true

  # No Public IP by default. See https://github.com/umccr/infrastructure/issues/432
  map_public_ip_on_launch = false

  # See README Subnet Tagging section for the following tags combination
  public_subnet_tags = {
    SubnetType            = var.umccr_subnet_tier.PUBLIC
    Tier                  = var.umccr_subnet_tier.PUBLIC
    "aws-cdk:subnet-name" = var.umccr_subnet_tier.PUBLIC
    "aws-cdk:subnet-type" = var.aws_cdk_subnet_type.PUBLIC
  }

  private_subnet_tags = {
    SubnetType            = var.umccr_subnet_tier.PRIVATE
    Tier                  = var.umccr_subnet_tier.PRIVATE
    "aws-cdk:subnet-name" = var.umccr_subnet_tier.PRIVATE
    "aws-cdk:subnet-type" = var.aws_cdk_subnet_type.PRIVATE
  }

  database_subnet_tags = {
    SubnetType            = var.umccr_subnet_tier.DATABASE
    Tier                  = var.umccr_subnet_tier.DATABASE
    "aws-cdk:subnet-name" = var.umccr_subnet_tier.DATABASE
    "aws-cdk:subnet-type" = var.aws_cdk_subnet_type.ISOLATED
  }

  tags = {
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

module "main_vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.1.2"

  vpc_id             = module.main_vpc.vpc_id
  security_group_ids = [data.aws_security_group.default_sg.id]

  # See below for config example
  # https://github.com/terraform-aws-modules/terraform-aws-vpc/tree/master/modules/vpc-endpoints
  # https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete-vpc/main.tf

  # Enable Gateway VPC endpoints for S3 and DynamoDB
  # No additional charge for using Gateway Endpoints https://docs.aws.amazon.com/vpc/latest/userguide/vpce-gateway.html

  # Note that Interface Endpoints are not free and use AWS PrivateLink https://aws.amazon.com/privatelink/pricing/
  # However it is still more cost effective than NAT Gateway for data communication within AWS Services

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([module.main_vpc.database_route_table_ids, module.main_vpc.private_route_table_ids, module.main_vpc.public_route_table_ids])
      tags            = { Name = "s3-vpc-endpoint" }
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = flatten([module.main_vpc.database_route_table_ids, module.main_vpc.private_route_table_ids, module.main_vpc.public_route_table_ids])
      # policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
      tags            = { Name = "dynamodb-vpc-endpoint" }
    },

    # Added ECR, ECS, Log VPC Interface Endpoints for Amazon Genomics CLI (AGC)
    # https://aws.github.io/amazon-genomics-cli/docs/concepts/accounts/#vpc-endpoints

    # Remove all Interface Endpoints. See https://trello.com/c/C861asAT

#    ecr_api = {
#      service         = "ecr.api"
#      subnet_ids      = module.main_vpc.private_subnets
#      tags            = { Name = "ecr-api-vpc-endpoint" }
#    },
#    ecr_dkr = {
#      service         = "ecr.dkr"
#      subnet_ids      = module.main_vpc.private_subnets
#      tags            = { Name = "ecr-dkr-vpc-endpoint" }
#    },
#    ecs = {
#      service         = "ecs"
#      subnet_ids      = module.main_vpc.private_subnets
#      tags            = { Name = "ecs-vpc-endpoint" }
#    },
#    ecs_agent = {
#      service         = "ecs-agent"
#      subnet_ids      = module.main_vpc.private_subnets
#      tags            = { Name = "ecs-agent-vpc-endpoint" }
#    },
#    ecs_telemetry = {
#      service         = "ecs-telemetry"
#      subnet_ids      = module.main_vpc.private_subnets
#      tags            = { Name = "ecs-telemetry-vpc-endpoint" }
#    },
#    logs = {
#      service         = "logs"
#      subnet_ids      = module.main_vpc.private_subnets
#      tags            = { Name = "logs-vpc-endpoint" }
#    }

  }

  tags = {
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

data "aws_security_group" "default_sg" {
  name   = "default"
  vpc_id = module.main_vpc.vpc_id
}

data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  statement {
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpce"
      values   = [module.main_vpc.vpc_id]
    }
  }
}

resource "aws_security_group" "main_vpc_sg_outbound" {
  name        = "main-vpc-sg-outbound"
  description = "Main VPC Security Group allow outbound only traffic"
  vpc_id      = module.main_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "outbound_only"
    Tier        = var.umccr_subnet_tier.PRIVATE
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

resource "aws_security_group" "main_vpc_sg_uom" {
  name        = "main-vpc-sg-uom"
  description = "Main VPC Security Group allow outbound traffic and UoM only inbound to SSH"
  vpc_id      = module.main_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["128.250.0.0/16"]  # UoM IP ranges https://ipinfo.io/AS10148
  }

  tags = {
    Name        = "ssh_from_uom"
    Tier        = var.umccr_subnet_tier.PRIVATE
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

# ---

# EC2 Instance Connect Endpoint (EICE)
# https://aws.amazon.com/blogs/compute/secure-connectivity-from-public-to-private-introducing-ec2-instance-connect-endpoint-june-13-2023/
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-with-ec2-instance-connect-endpoint.html
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/eice-quotas.html

resource "aws_security_group" "main_vpc_sg_eice" {
  name        = "main-vpc-sg-eice"
  description = "Main VPC Security Group allow traffic through EC2 Instance Connect Endpoint"
  vpc_id      = module.main_vpc.vpc_id

  # Allows SSH traffic within the VPC through this group
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ module.main_vpc.vpc_cidr_block ]
    self        = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ module.main_vpc.vpc_cidr_block ]
    self        = true
  }

  tags = {
    Name        = "ssh_from_eice"
    Tier        = var.umccr_subnet_tier.PRIVATE
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

resource "aws_ec2_instance_connect_endpoint" "main_vpc_eice" {
  subnet_id = module.main_vpc.private_subnets[0]  # az ap-southeast-2a

  security_group_ids = [
    aws_security_group.main_vpc_sg_eice.id,
  ]

  tags = {
    Name        = "main-vpc-eice"
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

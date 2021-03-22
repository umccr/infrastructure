terraform {
  required_version = ">= 0.14"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "networking/terraform.tfstate"
    region = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "~> 3.33.0"
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "ap-southeast-2"
}

resource "aws_eip" "main_vpc_nat_gateway" {
  count = 1
  vpc = true

  tags = {
    Name        = "main-vpc-nat-gateway-eip"
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

module "main_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

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

  # Enable Gateway VPC endpoints
  # No additional charge for using Gateway Endpoints https://docs.aws.amazon.com/vpc/latest/userguide/vpce-gateway.html
  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  # To enable more VPC Endpoints, see table in https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/
  # Note that Interface Endpoints are not free and use AWS PrivateLink https://aws.amazon.com/privatelink/pricing/
  # However it is still more cost effective than NAT Gateway for data communication within AWS Services
  # TODO monitor NAT Gateway cost +/- gradually enable most inter-communicated AWS Services depends on our usage here
  #enable_events_endpoint = true
  #enable_logs_endpoint = true
  #enable_monitoring_endpoint = true
  #enable_codebuild_endpoint = true
  #enable_codepipeline_endpoint = true
  #enable_ec2_endpoint = true
  #enable_ecs_endpoint = true
  #enable_ecr_dkr_endpoint = true
  #enable_ssm_endpoint = true
  #enable_sqs_endpoint = true
  #enable_sns_endpoint = true
  #enable_sts_endpoint = true

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
    cidr_blocks = ["10.1.0.0/20"]
  }

  tags = {
    Name        = "ssh_from_uom"
    Tier        = var.umccr_subnet_tier.PRIVATE
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

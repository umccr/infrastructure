terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "networking/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  version = "~> 2.64"
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
  version = "2.38.0"

  name = "main-vpc"
  cidr = "10.2.0.0/16"

  azs              = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  public_subnets   = ["10.2.0.0/23",  "10.2.2.0/23",  "10.2.4.0/23"]
  private_subnets  = ["10.2.20.0/23", "10.2.22.0/23", "10.2.24.0/23"]
  database_subnets = ["10.2.40.0/23", "10.2.42.0/23", "10.2.44.0/23"]

  // Single NAT Gateway Scenario
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

  public_subnet_tags = {
    SubnetType = "public"
    Tier       = var.public_tag
  }

  private_subnet_tags = {
    SubnetType = "private_app"
    Tier       = var.private_tag
  }

  database_subnet_tags = {
    SubnetType = "private_persistence"
    Tier       = var.database_tag
  }

  tags = {
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }
}

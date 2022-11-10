terraform {
  required_version = ">= 1.3.3"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_data_portal/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.38.0"
    }
  }
}

################################################################################
# Generic resources

provider "aws" {
  region = "ap-southeast-2"
}

# for ACM certificate
provider "aws" {
  region = "us-east-1"
  alias  = "use1"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  # Stack name in underscore
  stack_name_us = "data_portal"

  # Stack name in dash
  stack_name_dash = "data-portal"

  org_name = "umccr"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }

  data_portal_domain_prefix = "data"
  app_domain                = "${local.data_portal_domain_prefix}.${var.base_domain[terraform.workspace]}"

  api_domain    = "api.${local.app_domain}"
  iam_role_path = "/${local.stack_name_us}/"

  ssm_param_key_client_prefix  = "/${local.stack_name_us}/client"
  ssm_param_key_backend_prefix = "/${local.stack_name_us}/backend"
}

################################################################################
# Query for Pre-configured SSM Parameter Store
# These are pre-populated outside of terraform i.e. manually using Console or CLI

data "aws_ssm_parameter" "rds_db_password" {
  name = "/${local.stack_name_us}/${terraform.workspace}/rds_db_password"
}

data "aws_ssm_parameter" "rds_db_username" {
  name = "/${local.stack_name_us}/${terraform.workspace}/rds_db_username"
}

################################################################################
# Query Main VPC configurations from networking stack

data "aws_vpc" "main_vpc" {
  # Using tags filter on networking stack to get main-vpc
  tags = {
    Name        = "main-vpc"
    Stack       = "networking"
    Environment = terraform.workspace
  }
}

data "aws_subnets" "public_subnets_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Tier = "public"
  }
}

data "aws_subnets" "private_subnets_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Tier = "private"
  }
}

data "aws_subnets" "database_subnets_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Tier = "database"
  }
}

terraform {
  required_version = ">= 1.3.3"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_portal_workflow_automation/terraform.tfstate"
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

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  # Stack name in underscore
  stack_name_us = "data_portal"

  # Stack name in dash
  stack_name_dash = "data-portal"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }

  engine_parameters_default_workdir_root = {
    dev  = "gds://development/temp"
    prod = "gds://production/temp"
    stg  = "gds://staging/temp"
  }

  engine_parameters_default_output_root = {
    dev  = "gds://development"
    prod = "gds://production"
    stg  = "gds://staging"
  }
}

#--- Engine Parameter defaults

resource "aws_ssm_parameter" "workdir_root" {
  name        = "/iap/workflow/workdir_root"
  type        = "String"
  description = "Root directory for intermediate files for ica workflow"
  value       = local.engine_parameters_default_workdir_root[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "output_root" {
  name        = "/iap/workflow/output_root"
  type        = "String"
  description = "Root directory for output files for ica workflow"
  value       = local.engine_parameters_default_output_root[terraform.workspace]
  tags        = merge(local.default_tags)
}

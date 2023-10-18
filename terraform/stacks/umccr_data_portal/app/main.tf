terraform {
  required_version = ">= 1.5.7"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_portal_app/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.21.0"
    }
  }
}

################################################################################
# Generic resources

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  # Stack name in underscore
  stack_name_us = "data_portal"

  # Stack name in dash
  stack_name_dash = "data-portal"

  ssm_param_key_backend_prefix = "/${local.stack_name_us}/backend"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }

  notification_sns_topic_arn = {
    prod = data.aws_sns_topic.portal_ops_sns_topic.arn
    dev  = data.aws_sns_topic.chatbot_topic.arn
    stg  = data.aws_sns_topic.chatbot_topic.arn
  }
}

data "aws_sns_topic" "portal_ops_sns_topic" {
  name = "DataPortalTopic"
}

data "aws_sns_topic" "chatbot_topic" {
  name = "AwsChatBotTopic"
}

# see each app resources in their own tf files: s3.tf, report.tf

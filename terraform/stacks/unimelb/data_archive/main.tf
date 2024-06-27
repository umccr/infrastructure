terraform {
  required_version = ">= 1.3.3"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "data_archive/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

################################################################################
# Generic resources

# Configure the AWS Provider
provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  region                 = "ap-southeast-2"
  stack_name             = "data_archive"
  this_account_id        = data.aws_caller_identity.current.account_id
  mgmt_account_id        = "363226301494"
  cloudtrail_bucket_name = "cloudtrail-logs-${local.mgmt_account_id}-${local.region}"
  data_trail_name        = "dataTrail"

  default_tags = {
    "Stack"       = local.stack_name
    "Creator"     = "terraform"
    "Environment" = "data_archive"
  }
}

resource "aws_cloudtrail" "dataTrail" {
  name                          = local.data_trail_name
  s3_bucket_name                = local.cloudtrail_bucket_name

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }
  tags = merge(
    local.default_tags,
    {
      "umccr:Name" = local.data_trail_name
    }
  )
}

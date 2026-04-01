terraform {
  required_version = ">= 1.14.4"

  backend "s3" {
    bucket       = "terraform-states-363226301494-ap-southeast-2"
    key          = "management/billing/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.31.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}


provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      "umccr:Stack"       = "uom_management"
      "umccr:Environment" = "management"
      "umccr:Creator"     = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_ecr_authorization_token" "this" {}

locals {
  region          = data.aws_region.current.region
  this_account_id = data.aws_caller_identity.current.account_id

  # Computed identically to core/ — deterministic bucket name avoids a cross-stack dependency
  cloudtrail_bucket_name = "cloudtrail-logs-${local.this_account_id}-${local.region}"
}

provider "docker" {
  registry_auth {
    address  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com"
    username = "AWS"
    password = data.aws_ecr_authorization_token.this.password
  }
}

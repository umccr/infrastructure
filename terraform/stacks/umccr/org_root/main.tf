terraform {
  backend "s3" {
    bucket       = "umccr-terraform-states-org"
    key          = "org_root/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "local" {}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      "umccr:Stack"   = var.stack_name
      "umccr:Creator" = "Terraform"
    }
  }
}

data "aws_ecr_authorization_token" "this" {}

provider "docker" {
  registry_auth {
    address  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com"
    username = "AWS"
    password = data.aws_ecr_authorization_token.this.password
  }
}


################################################################################
# SNS

# hooks into chatbot to send messages to Slack
# we need to bring all of this infrastructure into terraform
# (currently some is made manually) (Patto Jan 2026)

resource "aws_sns_topic" "chatbot_slack_topic" {
  name_prefix  = "chatbot_slack_topic"
  display_name = "chatbot_slack_topic"
}

terraform {
  backend "s3" {
    bucket       = "umccr-terraform-states-org"
    key          = "org_root/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      "umccr:Stack"   = var.stack_name
      "umccr:Creator" = "Terraform"
    }
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

terraform {
  backend "s3" {
    bucket  = "umccr-terraform-meta"
    key     = "automation/production/terraform.tfstate"
    profile = "prod"
    region  = "ap-southeast-2"
  }
}

provider "aws" {
  # required AWS fields: aws_access_key_id, aws_secret_access_key, region
  profile = "${var.aws_profile}"
  region  = "${var.aws_region}"
}

# to get the account ID if needed
data "aws_caller_identity" "current" { }

module "travis_user" {
  source = "../../modules/iam_user/secure_user"
  username = "travis"
  pgp_key = "${var.pgp_key}"
}

resource "aws_iam_group" "automation_agents" {
  name = "automation_agents"
}

resource "aws_iam_group_membership" "automation_agents" {
  name = "automation_agents_group_membership"

  users = [
    "${module.travis_user.username}"
  ]

  group = "${aws_iam_group.automation_agents.name}"
}

resource "aws_iam_role" "automation_role" {
  name               = "automation_role"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.automation_assume_policy.json}"
}
data "aws_iam_policy_document" "automation_assume_policy" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = [ "ec2.amazonaws.com" ]
    }
    principals {
      type        = "Service"
      identifiers = [ "spotfleet.amazonaws.com" ]
    }
    principals {
      type        = "AWS"
      identifiers = [ "arn:aws:iam::472057503814:user/admin" ]
    }
  }
}

resource "aws_iam_policy" "ec2_automation_policy" {
  name   = "ec2_automation_policy"
  path   = "/"
  policy = "${file("policies/ec2_automation_policy.json")}"
}

resource "aws_iam_policy_attachment" "ec2_policy_to_automation_role_attachment" {
    name       = "ec2_policy_to_automation_role_attachment"
    policy_arn = "${aws_iam_policy.ec2_automation_policy.arn}"
    groups     = [ "${aws_iam_group.automation_agents.name}" ]
    users      = []
    roles      = [ "${aws_iam_role.automation_role.name}" ]
}

resource "aws_iam_policy_attachment" "spotfleet_policy_to_automation_role_attachment" {
    name       = "spotfleet_policy_to_automation_role_attachment"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
    groups     = [ "${aws_iam_group.automation_agents.name}" ]
    users      = []
    roles      = [ "${aws_iam_role.automation_role.name}" ]
}


resource "aws_iam_instance_profile" "packer_instance_profile" {
  name  = "packer_instance_profile"
  role = "${aws_iam_role.automation_role.name}"
}

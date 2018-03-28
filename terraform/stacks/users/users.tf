terraform {
  backend "s3" {
    bucket  = "umccr-terraform-bastion"
    key     = "bastion/terraform.tfstate"
    region  = "ap-southeast-2"
  }
}

provider "aws" {
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
  assume_role_policy = "${file("policies/automation_assume_role_policy.json")}"
}



data "template_file" "assume_automation_role_policy" {
    template = "${file("policies/assume_role_policy.json")}"
    vars {
        role_arn = "${aws_iam_role.automation_role.arn}"
    }
}
resource "aws_iam_policy" "agents_assume_automation_role_policy" {
  name   = "agents_assume_automation_role_policy"
  path   = "/"
  policy = "${data.template_file.assume_automation_role_policy.rendered}"
}
resource "aws_iam_policy_attachment" "agents_assume_automation_role_attachment" {
    name       = "ec2_policy_to_automation_role_attachment"
    policy_arn = "${aws_iam_policy.ec2_automation_policy.arn}"
    groups     = [ "${aws_iam_group.automation_agents.name}" ]
    users      = []
    roles      = []
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

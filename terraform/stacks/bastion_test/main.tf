terraform {
  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "bastion_test/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

################################################################################
##### create AWS users

module "console_users" {
  source = "../../modules/iam_user/secure_users"
  users  = "${var.console_users}"
}

resource "aws_iam_user_login_profile" "console_user_login" {
  count   = "${length(keys(var.console_users))}"
  user    = "${element(keys(var.console_users), count.index)}"
  pgp_key = "${element(values(var.console_users), count.index)}"
}

module "service_users" {
  source = "../../modules/iam_user/secure_users"
  users  = "${var.service_users}"
}

################################################################################
##### define user groups

# ops_admins_dev_no_mfa_users: admin access to the AWS dev account without requiring MFA
resource "aws_iam_group" "bastion_test_group" {
  name = "bastion_test_group"
}

resource "aws_iam_group_membership" "bastion_test_group_members" {
  name = "bastion_test_group_membership"

  users = [
    "user1",
    "user2",
    "service1",
    "service2",
  ]

  group = "${aws_iam_group.bastion_test_group.name}"
}

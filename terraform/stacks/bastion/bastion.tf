terraform {
  backend "s3" {
    bucket  = "umccr-terraform-bastion"
    key     = "bastion/terraform.tfstate"
    region  = "ap-southeast-2"
  }
}

provider "aws" {
  profile = "${var.aws_profile}"
  region  = "${var.aws_region}"
}


# create a user with minimal permissions
module "florian_user" {
  source = "../../modules/iam_user/secure_user"
  username = "florian"
  pgp_key = "${var.pgp_key}"
}
data "template_file" "get_user_policy" {
    template = "${file("policies/get_user.json")}"
    vars {
        user_arn = "${module.florian_user.arn}"
    }
}
resource "aws_iam_policy" "get_user_policy" {
  name   = "get_user_policy"
  path   = "/"
  policy = "${data.template_file.get_user_policy.rendered}"
}
resource "aws_iam_policy_attachment" "get_user_policy_florian_attachment" {
    name       = "get_user_policy_florian_attachment"
    policy_arn = "${aws_iam_policy.get_user_policy.arn}"
    groups     = []
    users      = [ "${module.florian_user.username}" ]
    roles      = []
}

# define groups
resource "aws_iam_group" "ops_admins_prod" {
  name = "ops_admins_prod"
}

# assign members to groups
resource "aws_iam_group_membership" "ops_admins_prod" {
  name = "ops_admins_group_membership"

  users = [
    "${module.florian_user.username}"
  ]

  group = "${aws_iam_group.ops_admins_prod.name}"
}

# define the assume role policy and define who can use it
data "template_file" "assume_ops_admin_role_policy" {
    template = "${file("policies/assume_role.json")}"
    vars {
        role_arn = "arn:aws:iam::472057503814:role/ops-admin"
    }
}
resource "aws_iam_policy" "assume_ops_admin_role_policy" {
  name   = "assume_ops_admin_role_policy"
  path   = "/"
  policy = "${data.template_file.assume_ops_admin_role_policy.rendered}"
}
resource "aws_iam_policy_attachment" "ops_admins_assume_ops_admin_role_attachment" {
    name       = "ec2_policy_to_automation_role_attachment"
    policy_arn = "${aws_iam_policy.assume_ops_admin_role_policy.arn}"
    groups     = [ "${aws_iam_group.ops_admins_prod.name}" ]
    users      = []
    roles      = []
}

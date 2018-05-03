terraform {
  backend "s3" {
    bucket  = "umccr-terraform-states"
    key     = "bastion/terraform.tfstate"
    region  = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region  = "ap-southeast-2"
}



# create a users with minimal permissions
module "florian_user" {
  source = "../../modules/iam_user/secure_user"
  username = "florian"
  pgp_key = "keybase:freisinger"
}
data "template_file" "get_user_florian_policy" {
    template = "${file("policies/get_user.json")}"
    vars {
        user_arn = "${module.florian_user.arn}"
    }
}
resource "aws_iam_policy" "get_user_florian_policy" {
  name   = "get_user_florian_policy"
  path   = "/"
  policy = "${data.template_file.get_user_florian_policy.rendered}"
}
resource "aws_iam_policy_attachment" "get_user_policy_florian_attachment" {
    name       = "get_user_policy_florian_attachment"
    policy_arn = "${aws_iam_policy.get_user_florian_policy.arn}"
    groups     = []
    users      = [ "${module.florian_user.username}" ]
    roles      = []
}

module "brainstorm_user" {
  source = "../../modules/iam_user/secure_user"
  username = "brainstorm"
  pgp_key = "keybase:brainstorm"
}
data "template_file" "get_user_brainstorm_policy" {
    template = "${file("policies/get_user.json")}"
    vars {
        user_arn = "${module.brainstorm_user.arn}"
    }
}
resource "aws_iam_policy" "get_user_brainstorm_policy" {
  name   = "get_user_brainstorm_policy"
  path   = "/"
  policy = "${data.template_file.get_user_brainstorm_policy.rendered}"
}
resource "aws_iam_policy_attachment" "get_user_policy_brainstorm_attachment" {
    name       = "get_user_policy_brainstorm_attachment"
    policy_arn = "${aws_iam_policy.get_user_brainstorm_policy.arn}"
    groups     = []
    users      = [ "${module.brainstorm_user.username}" ]
    roles      = []
}

module "packer_user" {
  source = "../../modules/iam_user/secure_user"
  username = "packer"
  pgp_key = "keybase:freisinger"
}
data "template_file" "get_user_packer_policy" {
    template = "${file("policies/get_user.json")}"
    vars {
        user_arn = "${module.packer_user.arn}"
    }
}
resource "aws_iam_policy" "get_user_packer_policy" {
  name   = "get_user_packer_policy"
  path   = "/"
  policy = "${data.template_file.get_user_packer_policy.rendered}"
}
resource "aws_iam_policy_attachment" "get_user_policy_packer_attachment" {
    name       = "get_user_policy_packer_attachment"
    policy_arn = "${aws_iam_policy.get_user_packer_policy.arn}"
    groups     = []
    users      = [ "${module.packer_user.username}" ]
    roles      = []
}

module "terraform_user" {
  source = "../../modules/iam_user/secure_user"
  username = "terraform"
  pgp_key = "keybase:freisinger"
}
data "template_file" "get_user_terraform_policy" {
    template = "${file("policies/get_user.json")}"
    vars {
        user_arn = "${module.terraform_user.arn}"
    }
}
resource "aws_iam_policy" "get_user_terraform_policy" {
  name   = "get_user_terraform_policy"
  path   = "/"
  policy = "${data.template_file.get_user_terraform_policy.rendered}"
}
resource "aws_iam_policy_attachment" "get_user_policy_terraform_attachment" {
    name       = "get_user_policy_terraform_attachment"
    policy_arn = "${aws_iam_policy.get_user_terraform_policy.arn}"
    groups     = []
    users      = [ "${module.terraform_user.username}" ]
    roles      = []
}

# define groups
resource "aws_iam_group" "ops_admins_prod" {
  name = "ops_admins_prod"
}
resource "aws_iam_group_membership" "ops_admins_prod" {
  name = "ops_admins_prod_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}"
  ]

  group = "${aws_iam_group.ops_admins_prod.name}"
}

resource "aws_iam_group" "ops_admins_dev" {
  name = "ops_admins_dev"
}
resource "aws_iam_group_membership" "ops_admins_dev" {
  name = "ops_admins_dev_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}"
  ]

  group = "${aws_iam_group.ops_admins_dev.name}"
}

resource "aws_iam_group" "packer_users" {
  name = "packer_users"
}
resource "aws_iam_group_membership" "packer_users" {
  name = "packer_users_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}",
    "${module.packer_user.username}"
  ]

  group = "${aws_iam_group.packer_users.name}"
}

resource "aws_iam_group" "ops_admins_dev_no_mfa_users" {
  name = "ops_admins_dev_no_mfa_users"
}
resource "aws_iam_group_membership" "ops_admins_dev_no_mfa_users" {
  name = "ops_admins_dev_no_mfa_users_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}",
    "${module.terraform_user.username}"
  ]

  group = "${aws_iam_group.ops_admins_dev_no_mfa_users.name}"
}


# define the assume role policy and define who can use it
data "template_file" "assume_ops_admin_prod_role_policy" {
    template = "${file("policies/assume_role.json")}"
    vars {
        role_arn = "arn:aws:iam::472057503814:role/ops-admin"
    }
}
resource "aws_iam_policy" "assume_ops_admin_prod_role_policy" {
  name   = "assume_ops_admin_prod_role_policy"
  path   = "/"
  policy = "${data.template_file.assume_ops_admin_prod_role_policy.rendered}"
}
resource "aws_iam_policy_attachment" "ops_admins_prod_assume_ops_admin_prod_role_attachment" {
    name       = "ops_admins_prod_assume_ops_admin_prod_role_attachment"
    policy_arn = "${aws_iam_policy.assume_ops_admin_prod_role_policy.arn}"
    groups     = [ "${aws_iam_group.ops_admins_prod.name}" ]
    users      = []
    roles      = []
}

data "template_file" "assume_ops_admin_dev_role_policy" {
    template = "${file("policies/assume_role.json")}"
    vars {
        role_arn = "arn:aws:iam::620123204273:role/ops-admin"
    }
}
resource "aws_iam_policy" "assume_ops_admin_dev_role_policy" {
  name   = "assume_ops_admin_dev_role_policy"
  path   = "/"
  policy = "${data.template_file.assume_ops_admin_dev_role_policy.rendered}"
}
resource "aws_iam_policy_attachment" "ops_admins_dev_assume_ops_admin_dev_role_attachment" {
    name       = "ops_admins_dev_assume_ops_admin_dev_role_attachment"
    policy_arn = "${aws_iam_policy.assume_ops_admin_dev_role_policy.arn}"
    groups     = [ "${aws_iam_group.ops_admins_dev.name}" ]
    users      = []
    roles      = []
}

data "template_file" "assume_packer_role_policy" {
    template = "${file("policies/assume_role_no_mfa.json")}"
    vars {
        role_arn = "arn:aws:iam::620123204273:role/packer_role"
    }
}
resource "aws_iam_policy" "assume_packer_role_policy" {
  name   = "assume_packer_role_policy"
  path   = "/"
  policy = "${data.template_file.assume_packer_role_policy.rendered}"
}
resource "aws_iam_policy_attachment" "packer_assume_packer_role_attachment" {
    name       = "packer_assume_packer_role_attachment"
    policy_arn = "${aws_iam_policy.assume_packer_role_policy.arn}"
    groups     = [ "${aws_iam_group.packer_users.name}" ]
    users      = []
    roles      = []
}

data "template_file" "assume_ops_admin_dev_no_mfa_role_policy" {
    template = "${file("policies/assume_role_no_mfa.json")}"
    vars {
        role_arn = "arn:aws:iam::620123204273:role/ops_admin_no_mfa"
    }
}
resource "aws_iam_policy" "assume_ops_admin_dev_no_mfa_role_policy" {
  name   = "assume_ops_admin_dev_no_mfa_role_policy"
  path   = "/"
  policy = "${data.template_file.assume_ops_admin_dev_no_mfa_role_policy.rendered}"
}
resource "aws_iam_policy_attachment" "terraform_assume_terraform_role_attachment" {
    name       = "terraform_assume_terraform_role_attachment"
    policy_arn = "${aws_iam_policy.assume_ops_admin_dev_no_mfa_role_policy.arn}"
    groups     = [ "${aws_iam_group.ops_admins_dev_no_mfa_users.name}" ]
    users      = []
    roles      = []
}

terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "bastion/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

################################################################################
##### create AWS users

# florian
module "florian_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "florian"
  pgp_key  = "keybase:freisinger"
}

resource "aws_iam_user_login_profile" "florian_console_login" {
  user    = "${module.florian_user.username}"
  pgp_key = "keybase:freisinger"
}

# brainstorm
module "brainstorm_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "brainstorm"
  pgp_key  = "keybase:brainstorm"
}

resource "aws_iam_user_login_profile" "brainstorm_console_login" {
  user    = "${module.brainstorm_user.username}"
  pgp_key = "keybase:brainstorm"
}

# oliver
module "oliver_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "oliver"
  pgp_key  = "keybase:ohofmann"
}

resource "aws_iam_user_login_profile" "oliver_console_login" {
  user    = "${module.oliver_user.username}"
  pgp_key = "keybase:ohofmann"
}

# vlad
module "vlad_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "vlad"
  pgp_key  = "keybase:vladsaveliev"
}

resource "aws_iam_user_login_profile" "vlad_console_login" {
  user    = "${module.vlad_user.username}"
  pgp_key = "keybase:vladsaveliev"
}

# lavinia
module "lavinia_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "lavinia"
  pgp_key  = "keybase:lavinia"
}

resource "aws_iam_user_login_profile" "lavinia_console_login" {
  user    = "${module.lavinia_user.username}"
  pgp_key = "keybase:lavinia"
}

# pdiakumis
module "pdiakumis_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "pdiakumis"
  pgp_key  = "keybase:pdiakumis"
}

resource "aws_iam_user_login_profile" "pdiakumis_console_login" {
  user    = "${module.pdiakumis_user.username}"
  pgp_key = "keybase:pdiakumis"
}

# sehrishk
module "sehrishk_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "sehrishk"
  pgp_key  = "keybase:sehrishk"
}

resource "aws_iam_user_login_profile" "sehrishk_console_login" {
  user    = "${module.sehrishk_user.username}"
  pgp_key = "keybase:sehrishk"
}

##### create service users

# packer
module "packer_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "packer"
  pgp_key  = "keybase:freisinger"
}

# terraform
module "terraform_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "terraform"
  pgp_key  = "keybase:freisinger"
}

# umccr_pipeline
module "umccr_pipeline_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "umccr_pipeline"
  pgp_key  = "keybase:freisinger"
}

################################################################################
##### define user groups

# ops_admins_prod: admin access to the AWS prod account
resource "aws_iam_group" "ops_admins_prod" {
  name = "ops_admins_prod"
}

resource "aws_iam_group_membership" "ops_admins_prod" {
  name = "ops_admins_prod_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}",
  ]

  group = "${aws_iam_group.ops_admins_prod.name}"
}

# ops_admins_dev: admin access to the AWS dev account
resource "aws_iam_group" "ops_admins_dev" {
  name = "ops_admins_dev"
}

resource "aws_iam_group_membership" "ops_admins_dev" {
  name = "ops_admins_dev_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}",
    "${module.vlad_user.username}",
  ]

  group = "${aws_iam_group.ops_admins_dev.name}"
}

# packer_users: users allowed to assume the packer role
resource "aws_iam_group" "packer_users" {
  name = "packer_users"
}

resource "aws_iam_group_membership" "packer_users" {
  name = "packer_users_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}",
    "${module.packer_user.username}",
  ]

  group = "${aws_iam_group.packer_users.name}"
}

# ops_admins_dev_no_mfa_users: admin access to the AWS dev account without requiring MFA
resource "aws_iam_group" "ops_admins_dev_no_mfa_users" {
  name = "ops_admins_dev_no_mfa_users"
}

resource "aws_iam_group_membership" "ops_admins_dev_no_mfa_users" {
  name = "ops_admins_dev_no_mfa_users_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}",
    "${module.vlad_user.username}",
    "${module.oliver_user.username}",
    "${module.terraform_user.username}",
    "${module.lavinia_user.username}",
    "${module.pdiakumis_user.username}",
    "${module.sehrishk_user.username}",
  ]

  group = "${aws_iam_group.ops_admins_dev_no_mfa_users.name}"
}

# fastq_data_uploaders: users allowed to assume the fastq_uploader role, 
# which gives access to selected S3 buckets on prod without requiring MFA
resource "aws_iam_group" "fastq_data_uploaders" {
  name = "fastq_data_uploaders"
}

resource "aws_iam_group_membership" "fastq_data_uploaders" {
  name = "ops_admins_dev_no_mfa_users_group_membership"

  users = [
    "${module.florian_user.username}",
    "${module.brainstorm_user.username}",
    "${module.oliver_user.username}",
    "${module.vlad_user.username}",
    "${module.terraform_user.username}",
  ]

  group = "${aws_iam_group.fastq_data_uploaders.name}"
}

################################################################################
# define the assume role policies and who can use them

# ops-admin role (on prod)
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
  groups     = ["${aws_iam_group.ops_admins_prod.name}"]
  users      = []
  roles      = []
}

# ops-admin role (on dev)
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
  groups     = ["${aws_iam_group.ops_admins_dev.name}"]
  users      = []
  roles      = []
}

# packer_role (on dev)
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
  groups     = ["${aws_iam_group.packer_users.name}"]
  users      = []
  roles      = []
}

# ops_admin_no_mfa (on dev)
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
  groups     = ["${aws_iam_group.ops_admins_dev_no_mfa_users.name}"]
  users      = []
  roles      = []
}

# fastq_data_uploader role (on prod)
data "template_file" "assume_fastq_data_uploader_prod_policy" {
  template = "${file("policies/assume_role_no_mfa.json")}"

  vars {
    role_arn = "arn:aws:iam::472057503814:role/fastq_data_uploader"
  }
}

resource "aws_iam_policy" "assume_fastq_data_uploader_prod_policy" {
  name   = "assume_fastq_data_uploader_prod_policy"
  path   = "/"
  policy = "${data.template_file.assume_fastq_data_uploader_prod_policy.rendered}"
}

resource "aws_iam_policy_attachment" "assume_fastq_data_uploader_prod_role_attachment" {
  name       = "assume_fastq_data_uploader_prod_role_attachment"
  policy_arn = "${aws_iam_policy.assume_fastq_data_uploader_prod_policy.arn}"
  groups     = ["${aws_iam_group.fastq_data_uploaders.name}"]
  users      = []
  roles      = []
}

# fastq_data_uploader (on dev)
data "template_file" "assume_fastq_data_uploader_dev_policy" {
  template = "${file("policies/assume_role_no_mfa.json")}"

  vars {
    role_arn = "arn:aws:iam::620123204273:role/fastq_data_uploader"
  }
}

resource "aws_iam_policy" "assume_fastq_data_uploader_dev_policy" {
  name   = "assume_fastq_data_uploader_dev_policy"
  path   = "/"
  policy = "${data.template_file.assume_fastq_data_uploader_dev_policy.rendered}"
}

resource "aws_iam_policy_attachment" "assume_fastq_data_uploader_dev_role_attachment" {
  name       = "assume_fastq_data_uploader_dev_role_attachment"
  policy_arn = "${aws_iam_policy.assume_fastq_data_uploader_dev_policy.arn}"
  groups     = ["${aws_iam_group.fastq_data_uploaders.name}"]
  users      = []
  roles      = []
}

# umccr_pipeline (dev)
data "template_file" "assume_umccr_pipeline_dev_policy" {
  template = "${file("policies/assume_role_no_mfa.json")}"

  vars {
    role_arn = "arn:aws:iam::620123204273:role/umccr_pipeline"
  }
}

resource "aws_iam_policy" "assume_umccr_pipeline_dev_policy" {
  name   = "assume_umccr_pipeline_dev_policy"
  path   = "/"
  policy = "${data.template_file.assume_umccr_pipeline_dev_policy.rendered}"
}

resource "aws_iam_policy_attachment" "assume_umccr_pipeline_dev_role_attachment" {
  name       = "assume_umccr_pipeline_dev_role_attachment"
  policy_arn = "${aws_iam_policy.assume_umccr_pipeline_dev_policy.arn}"
  groups     = []
  users      = ["${module.umccr_pipeline_user.username}"]
  roles      = []
}

# umccr_pipeline (prod)
data "template_file" "assume_umccr_pipeline_prod_policy" {
  template = "${file("policies/assume_role_no_mfa.json")}"

  vars {
    role_arn = "arn:aws:iam::472057503814:role/umccr_pipeline"
  }
}

resource "aws_iam_policy" "assume_umccr_pipeline_prod_policy" {
  name   = "assume_umccr_pipeline_prod_policy"
  path   = "/"
  policy = "${data.template_file.assume_umccr_pipeline_prod_policy.rendered}"
}

resource "aws_iam_policy_attachment" "assume_umccr_pipeline_prod_role_attachment" {
  name       = "assume_umccr_pipeline_prod_role_attachment"
  policy_arn = "${aws_iam_policy.assume_umccr_pipeline_prod_policy.arn}"
  groups     = []
  users      = ["${module.umccr_pipeline_user.username}"]
  roles      = []
}

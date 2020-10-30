terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    bucket         = "agha-terraform-states"
    key            = "agha_gdr/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  common_tags = "${map(
    "Environment", "agha",
    "Stack", "${var.stack_name}"
  )}"
}

################################################################################
# S3 buckets

data "aws_s3_bucket" "agha_gdr_staging" {
  bucket = "${var.agha_gdr_staging_bucket_name}"
}

data "aws_s3_bucket" "agha_gdr_store" {
  bucket = "${var.agha_gdr_store_bucket_name}"
}


################################################################################
# Dedicated user to generate long lived presigned URLs
# See: https://aws.amazon.com/premiumsupport/knowledge-center/presigned-url-s3-bucket-expiration/

module "agha_bot_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "agha_bot"
  pgp_key  = "keybase:freisinger"
}

resource "aws_iam_user_policy_attachment" "ahga_bot_staging_rw" {
  user       = "${module.agha_bot_user.username}"
  policy_arn = "${aws_iam_policy.agha_staging_rw_policy.arn}"
}

resource "aws_iam_user_policy_attachment" "ahga_bot_store_ro" {
  user       = "${module.agha_bot_user.username}"
  policy_arn = "${aws_iam_policy.agha_store_ro_policy.arn}"
}

################################################################################
# Users & groups

module "simonsadedin" {
  source   = "../../modules/iam_user/secure_user"
  username = "simonsadedin"
  pgp_key  = "keybase:simonsadedin"
  email    = "simon.sadedin@vcgs.org.au"
}

module "shyrav" {
  source   = "../../modules/iam_user/secure_user"
  username = "shyrav"
  pgp_key  = "keybase:freisinger"
  email    = "s.ravishankar@garvan.org.au"
}

module "rk_chw" {
  source   = "../../modules/iam_user/secure_user"
  username = "rk_chw"
  pgp_key  = "keybase:freisinger"
  email    = "rahul.krishnaraj@health.nsw.gov.au"
}

module "seanlianu" {
  source   = "../../modules/iam_user/secure_user"
  username = "seanlianu"
  pgp_key  = "keybase:freisinger"
  email    = "sean.li@anu.edu.au"
}

module "sgao" {
  source   = "../../modules/iam_user/secure_user"
  username = "sgao"
  pgp_key  = "keybase:freisinger"
  email    = "song.gao@sa.gov.au"
}

# Special user (sarah) for AGHA data manager/curator
module "sarah" {
  source   = "../../modules/iam_user/secure_user"
  username = "sarah"
  pgp_key  = "keybase:freisinger"
  email    = "sarah.casauria@mcri.edu.au"
}

resource "aws_iam_user_login_profile" "sarah_console_login" {
  user    = "${module.sarah.username}"
  pgp_key = "keybase:freisinger"
}

# groups
resource "aws_iam_group" "admin" {
  name = "agha_gdr_admins"
}

resource "aws_iam_group" "submit" {
  name = "agha_gdr_submit"
}

resource "aws_iam_group" "read" {
  name = "agha_gdr_read"
}

resource "aws_iam_group_membership" "submit_members" {
  name  = "${aws_iam_group.submit.name}_membership"
  users = [
    "${module.simonsadedin.username}",
    "${module.rk_chw.username}",
    "${module.seanlianu.username}",
    "${module.sgao.username}"
  ]
  group = "${aws_iam_group.submit.name}"
}

resource "aws_iam_group_membership" "read_members" {
  name  = "${aws_iam_group.read.name}_membership"
  users = [
    "${module.shyrav.username}"
  ]
  group = "${aws_iam_group.read.name}"
}

################################################################################
# Create access policies

data "template_file" "agha_staging_ro_policy" {
  template = "${file("policies/bucket-ro-policy.json")}"

  vars {
    bucket_name = "${data.aws_s3_bucket.agha_gdr_staging.id}"
  }
}

data "template_file" "agha_staging_rw_policy" {
  template = "${file("policies/bucket-rw-policy.json")}"

  vars {
    bucket_name = "${data.aws_s3_bucket.agha_gdr_staging.id}"
  }
}

data "template_file" "agha_store_ro_policy" {
  template = "${file("policies/bucket-ro-policy.json")}"

  vars {
    bucket_name = "${data.aws_s3_bucket.agha_gdr_store.id}"
  }
}

data "template_file" "agha_store_rw_policy" {
  template = "${file("policies/bucket-rw-policy.json")}"

  vars {
    bucket_name = "${data.aws_s3_bucket.agha_gdr_store.id}"
  }
}

data "template_file" "agha_store_list_policy" {
  template = "${file("policies/bucket-list-policy.json")}"

  vars {
    bucket_name = "${data.aws_s3_bucket.agha_gdr_store.id}"
  }
}

resource "aws_iam_policy" "agha_staging_ro_policy" {
  name   = "agha_staging_ro_policy"
  path   = "/"
  policy = "${data.template_file.agha_staging_ro_policy.rendered}"
}

resource "aws_iam_policy" "agha_staging_rw_policy" {
  name   = "agha_staging_rw_policy"
  path   = "/"
  policy = "${data.template_file.agha_staging_rw_policy.rendered}"
}

resource "aws_iam_policy" "agha_store_ro_policy" {
  name   = "agha_store_ro_policy"
  path   = "/"
  policy = "${data.template_file.agha_store_ro_policy.rendered}"
}

resource "aws_iam_policy" "agha_store_rw_policy" {
  name   = "agha_store_rw_policy"
  path   = "/"
  policy = "${data.template_file.agha_store_rw_policy.rendered}"
}

resource "aws_iam_policy" "agha_store_list_policy" {
  name   = "agha_store_list_policy"
  path   = "/"
  policy = "${data.template_file.agha_store_list_policy.rendered}"
}

################################################################################
# Attach policies to user groups

# admin group policies
resource "aws_iam_group_policy_attachment" "admin_staging_rw_policy_attachment" {
  group      = "${aws_iam_group.admin.name}"
  policy_arn = "${aws_iam_policy.agha_staging_rw_policy.arn}"
}

resource "aws_iam_group_policy_attachment" "admin_store_rw_policy_attachment" {
  group      = "${aws_iam_group.admin.name}"
  policy_arn = "${aws_iam_policy.agha_store_rw_policy.arn}"
}

# submit group policies
resource "aws_iam_group_policy_attachment" "submit_store_rw_policy_attachment" {
  group      = "${aws_iam_group.submit.name}"
  policy_arn = "${aws_iam_policy.agha_staging_rw_policy.arn}"
}

resource "aws_iam_group_policy_attachment" "submit_store_ro_policy_attachment" {
  group      = "${aws_iam_group.submit.name}"
  policy_arn = "${aws_iam_policy.agha_store_ro_policy.arn}"
}

# read group policies
resource "aws_iam_group_policy_attachment" "read_store_rw_policy_attachment" {
  group      = "${aws_iam_group.read.name}"
  policy_arn = "${aws_iam_policy.agha_store_ro_policy.arn}"
}

# permission attachments for data manager
resource "aws_iam_user_policy_attachment" "ro_staging_sarah" {
  user       = "${module.sarah.username}"
  policy_arn = "${aws_iam_policy.agha_staging_ro_policy.arn}"
}

resource "aws_iam_user_policy_attachment" "ro_store_sarah" {
  user       = "${module.sarah.username}"
  policy_arn = "${aws_iam_policy.agha_store_ro_policy.arn}"
}


resource "aws_iam_policy" "agha_data_manager_policy" {
  name   = "agha_data_manager_policy"
  path   = "/"
  policy = "${file("policies/data_manager_policy.json")}"
}
resource "aws_iam_user_policy_attachment" "agha_data_manager_policy" {
  user       = "${module.sarah.username}"
  policy_arn = "${aws_iam_policy.agha_data_manager_policy.arn}"
}

resource "aws_iam_policy" "default_user_policy" {
  name   = "default_user_policy"
  path   = "/"
  policy = "${file("policies/default_user_policy.json")}"
}
resource "aws_iam_user_policy_attachment" "default_user_policy" {
  user       = "${module.sarah.username}"
  policy_arn = "${aws_iam_policy.default_user_policy.arn}"
}
resource "aws_iam_group_policy_attachment" "admin_default_user_attachment" {
  group      = "${aws_iam_group.admin.name}"
  policy_arn = "${aws_iam_policy.default_user_policy.arn}"
}

resource "aws_iam_group_policy_attachment" "submit_default_user_attachment" {
  group      = "${aws_iam_group.submit.name}"
  policy_arn = "${aws_iam_policy.default_user_policy.arn}"
}

resource "aws_iam_group_policy_attachment" "read_default_user_attachment" {
  group      = "${aws_iam_group.read.name}"
  policy_arn = "${aws_iam_policy.default_user_policy.arn}"
}

terraform {
  required_version = ">= 0.12.6"

  backend "s3" {
    bucket         = "agha-terraform-states"
    key            = "agha_users/terraform.tfstate"
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
  common_tags = map(
    "Environment", "agha",
    "Stack", var.stack_name
  )
}

################################################################################
# S3 buckets

data "aws_s3_bucket" "agha_gdr_staging" {
  bucket = var.agha_gdr_staging_bucket_name
}

data "aws_s3_bucket" "agha_gdr_store" {
  bucket = var.agha_gdr_store_bucket_name
}


################################################################################
# Users

# # Dedicated user to generate long lived presigned URLs
# # See: https://aws.amazon.com/premiumsupport/knowledge-center/presigned-url-s3-bucket-expiration/
module "agha_presign" {
  source    = "../../modules/iam_user/default_user"
  username  = "agha_presign"
  pgp_key   = "keybase:freisinger"
}

# AGHA Users
module "simon" {
  source    = "../../modules/iam_user/default_user"
  username  = "simon"
  full_name = "Simon Sadedin"
  keybase   = "simonsadedin"
  pgp_key   = "keybase:freisinger"
  email     = "simon.sadedin@vcgs.org.au"
}

module "shyrav" {
  source    = "../../modules/iam_user/default_user"
  username  = "shyrav"
  full_name = "Shyamsundar Ravishankar"
  keybase   = "shyrav"
  pgp_key   = "keybase:freisinger"
  email     = "s.ravishankar@garvan.org.au"
}

module "rk_chw" {
  source    = "../../modules/iam_user/default_user"
  username  = "rk_chw"
  full_name = "Rahul Krishnaraj"
  keybase   = "rk_chw"
  pgp_key   = "keybase:freisinger"
  email     = "rahul.krishnaraj@health.nsw.gov.au"
}

module "yingzhu" {
  source    = "../../modules/iam_user/default_user"
  username  = "yingzhu"
  full_name = "Ying Zhu"
  keybase   = "yingzhu"
  pgp_key   = "keybase:freisinger"
  email     = "Ying.Zhu@health.nsw.gov.au"
}

module "seanlianu" {
  source    = "../../modules/iam_user/default_user"
  username  = "seanlianu"
  full_name = "Sean Li"
  keybase   = "seanlianu"
  pgp_key   = "keybase:freisinger"
  email     = "sean.li@anu.edu.au"
}

# Data Manager/Controller
module "sarah_dm" {
  source    = "../../modules/iam_user/default_user"
  username  = "sarah_dm"
  full_name = "Sarah Casauria"
  keybase   = "scasauria"
  pgp_key   = "keybase:freisinger"
  email     = "sarah.casauria@mcri.edu.au"
}
resource "aws_iam_user_login_profile" "sarah_dm" {
  user    = module.sarah_dm.username
  pgp_key = "keybase:freisinger"
}

################################################################################
# Groups

# Default
resource "aws_iam_group" "default" {
  name = "agha_gdr_default"
  path = "/agha/"
}

# Submitters
resource "aws_iam_group" "submitter" {
  name = "agha_gdr_submitters"
  path = "/agha/"
}

# Consumers
resource "aws_iam_group" "consumer" {
  name = "agha_gdr_consumers"
  path = "/agha/"
}

# Data Controllers
resource "aws_iam_group" "data_controller" {
  name = "agha_gdr_controller"
  path = "/agha/"
}

####################
# Group memberships

# Default
resource "aws_iam_group_membership" "default" {
  name  = "${aws_iam_group.default.name}_membership"
  group = aws_iam_group.default.name
  users = [
    module.rk_chw.username,
    module.sarah_dm.username,
    module.shyrav.username,
    module.simon.username,
    module.yingzhu.username,
    module.seanlianu.username,
  ]
}

resource "aws_iam_group_policy_attachment" "default_user_policy_attachment" {
  group      = aws_iam_group.default.name
  policy_arn = aws_iam_policy.default_user_policy.arn
}

# Submitters
resource "aws_iam_group_membership" "submitter" {
  name  = "${aws_iam_group.submitter.name}_membership"
  group = aws_iam_group.submitter.name
  users = [
    module.agha_presign.username,
    module.rk_chw.username,
    module.simon.username,
    module.yingzhu.username,
    module.seanlianu.username,
  ]
}

resource "aws_iam_group_policy_attachment" "submit_staging_rw_policy_attachment" {
  group      = aws_iam_group.submitter.name
  policy_arn = aws_iam_policy.agha_staging_rw_policy.arn
}

resource "aws_iam_group_policy_attachment" "submit_store_ro_policy_attachment" {
  group      = aws_iam_group.submitter.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}

# Consumers
resource "aws_iam_group_membership" "consumer" {
  name  = "${aws_iam_group.consumer.name}_membership"
  group = aws_iam_group.consumer.name
  users = [
    module.shyrav.username
  ]
}

resource "aws_iam_group_policy_attachment" "consumer_store_ro_policy_attachment" {
  group      = aws_iam_group.consumer.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}

# Controllers
resource "aws_iam_group_membership" "data_controller" {
  name  = "${aws_iam_group.data_controller.name}_membership"
  group = aws_iam_group.data_controller.name
  users = [
    module.sarah_dm.username
  ]
}

resource "aws_iam_group_policy_attachment" "controller_additional_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.data_controller_policy.arn
}

resource "aws_iam_group_policy_attachment" "controller_staging_ro_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.agha_staging_ro_policy.arn
}

resource "aws_iam_group_policy_attachment" "controller_store_ro_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}


################################################################################
# Create access policies

data "template_file" "agha_staging_ro_policy" {
  template = file("policies/bucket-ro-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_staging.id
  }
}

data "template_file" "agha_staging_rw_policy" {
  template = file("policies/bucket-rw-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_staging.id
  }
}

data "template_file" "agha_store_ro_policy" {
  template = file("policies/bucket-ro-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_store.id
  }
}

resource "aws_iam_policy" "default_user_policy" {
  name_prefix = "default_user_policy"
  path        = "/agha/"
  policy = file("policies/default-user-policy.json")
}

resource "aws_iam_policy" "data_controller_policy" {
  name_prefix = "data_controller_policy"
  path        = "/agha/"
  policy = file("policies/data-controller-policy.json")
}

resource "aws_iam_policy" "agha_staging_ro_policy" {
  name_prefix = "agha_staging_ro_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_staging_ro_policy.rendered
}

resource "aws_iam_policy" "agha_staging_rw_policy" {
  name_prefix = "agha_staging_rw_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_staging_rw_policy.rendered
}

resource "aws_iam_policy" "agha_store_ro_policy" {
  name_prefix = "agha_store_ro_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_store_ro_policy.rendered
}

################################################################################

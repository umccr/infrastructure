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
  common_tags = {
    "Environment" : "agha",
    "Stack" : var.stack_name
  }
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
  source   = "../../modules/iam_user/default_user"
  username = "agha_presign"
  pgp_key  = "keybase:freisinger"
}

#####
# AGHA Users
# NOTE: we don't manage access keys via Terraform as that would interfere with
#       users rotating their access keys themselves. So upon user creation the
#       initial access key will have to be created manually for the user.
resource "aws_iam_user" "adavawala" {
  name          = "adavawala"
  path          = "/agha/"
  force_destroy = true
  tags = {
    email   = "ashil.davawala@vcgs.org.au",
    name    = "Ashil Davawala",
    keybase = "adavawala"
  }
}

resource "aws_iam_user" "richardallcock" {
  name          = "richardallcock"
  path          = "/agha/"
  force_destroy = true
  tags = {
    email   = "Richard.Allcock@health.wa.gov.au",
    name    = "Richard Allcock",
    keybase = "richardallcock"
  }
}

resource "aws_iam_user" "evachan" {
  name          = "evachan"
  path          = "/agha/"
  force_destroy = true
  tags = {
    email   = "eva.chan@health.nsw.gov.au",
    name    = "Eva Chan",
    keybase = "evachan"
  }
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
    module.sarah_dm.username,
    aws_iam_user.adavawala.name,
    aws_iam_user.evachan.name,
    aws_iam_user.richardallcock.name,
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
    module.sarah_dm.username,
    aws_iam_user.adavawala.name,
    aws_iam_user.richardallcock.name,
  ]
}

resource "aws_iam_group_policy_attachment" "submit_staging_rw_policy_attachment" {
  group      = aws_iam_group.submitter.name
  policy_arn = aws_iam_policy.agha_staging_submit_policy.arn
}

# Controllers
resource "aws_iam_group_membership" "data_controller" {
  name  = "${aws_iam_group.data_controller.name}_membership"
  group = aws_iam_group.data_controller.name
  users = [
    module.agha_presign.username,
    module.sarah_dm.username
  ]
}

resource "aws_iam_group_policy_attachment" "controller_additional_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.data_controller_policy.arn
}

resource "aws_iam_group_policy_attachment" "controller_staging_manage_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.agha_staging_manage_policy.arn
}

resource "aws_iam_group_policy_attachment" "controller_store_ro_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}

resource "aws_iam_group_policy_attachment" "controller_dynamodb_ro_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = var.policy_arn_dynamodb_ro
}

################################################################################
# Create access policies

# # test policy to experiment with policy templates for flagship specific access permissions
# resource "aws_iam_policy" "agha_staging_rbac_mito_policy" {
#   name_prefix = "test_template_policy"
#   path        = "/agha/"
#   policy = templatefile("policies/bucket-rbac-flagship-template-policy.json", {
#     bucket_name = data.aws_s3_bucket.agha_gdr_staging.id, 
#     prefixes = ["Mito/*"],
#     consent_group = "True"
#     })
# }

resource "aws_iam_policy" "default_user_policy" {
  name_prefix = "default_user_policy"
  path        = "/agha/"
  policy      = file("policies/default-user-policy.json")
}

resource "aws_iam_policy" "data_controller_policy" {
  name_prefix = "data_controller_policy"
  path        = "/agha/"
  policy      = file("policies/data-controller-policy.json")
}

data "template_file" "agha_staging_manage_policy" {
  template = file("policies/bucket-manage-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_staging.id
  }
}
resource "aws_iam_policy" "agha_staging_manage_policy" {
  name_prefix = "agha_staging_ro_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_staging_manage_policy.rendered
}

data "template_file" "agha_staging_ro_policy" {
  template = file("policies/bucket-ro-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_staging.id
  }
}
resource "aws_iam_policy" "agha_staging_ro_policy" {
  name_prefix = "agha_staging_ro_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_staging_ro_policy.rendered
}

data "template_file" "agha_staging_submit_policy" {
  template = file("policies/bucket-submit-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_staging.id
  }
}
resource "aws_iam_policy" "agha_staging_submit_policy" {
  name_prefix = "agha_staging_submit_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_staging_submit_policy.rendered
}

data "template_file" "agha_store_ro_policy" {
  template = file("policies/bucket-ro-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_store.id
  }
}
resource "aws_iam_policy" "agha_store_ro_policy" {
  name_prefix = "agha_store_ro_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_store_ro_policy.rendered
}

################################################################################

## Consented data access test

data "template_file" "abac_store_policy" {
  template = file("policies/bucket-ro-abac-s3-policy.json")

  vars = {
    bucket_name   = data.aws_s3_bucket.agha_gdr_store.id,
    consent_group = "True"
  }
}

resource "aws_iam_policy" "abac_store_policy" {
  name_prefix = "agha_store_abac_policy"
  path        = "/agha/"
  policy      = data.template_file.abac_store_policy.rendered
}

data "template_file" "abac_staging_policy" {
  template = file("policies/bucket-ro-abac-s3-policy.json")

  vars = {
    bucket_name   = data.aws_s3_bucket.agha_gdr_staging.id,
    consent_group = "True"
  }
}

resource "aws_iam_policy" "abac_staging_policy" {
  name_prefix = "agha_store_abac_policy"
  path        = "/agha/"
  policy      = data.template_file.abac_staging_policy.rendered
}

resource "aws_iam_user" "abac" {
  name = "abac"
  path = "/agha/"
  tags = {
    name    = "ABAC Test",
    keybase = "abac"
  }
}

# group
resource "aws_iam_group" "abac" {
  name = "agha_gdr_abac"
  path = "/agha/"
}

# group membership
resource "aws_iam_group_membership" "abac" {
  name  = "${aws_iam_group.abac.name}_membership"
  group = aws_iam_group.abac.name
  users = [
    aws_iam_user.abac.name
  ]
}

# group policies
resource "aws_iam_group_policy_attachment" "abac_store_policy_attachment" {
  group      = aws_iam_group.abac.name
  policy_arn = aws_iam_policy.abac_store_policy.arn
}
resource "aws_iam_group_policy_attachment" "abac_staging_policy_attachment" {
  group      = aws_iam_group.abac.name
  policy_arn = aws_iam_policy.abac_staging_policy.arn
}

################################################################################

## Mackenzie's Mission

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
# Users

# # Dedicated user to generate long lived presigned URLs
# # See: https://aws.amazon.com/premiumsupport/knowledge-center/presigned-url-s3-bucket-expiration/
# module "agha_bot_user" {
#   source   = "../../modules/iam_user/default_user"
#   username = "agha_bot"
# }

# resource "aws_iam_user_policy_attachment" "ahga_bot_staging_ro" {
#   user       = module.agha_bot_user.username
#   policy_arn = aws_iam_policy.agha_staging_ro_policy.arn
# }

# resource "aws_iam_user_policy_attachment" "ahga_bot_store_ro" {
#   user       = module.agha_bot_user.username
#   policy_arn = aws_iam_policy.agha_store_ro_policy.arn
# }

# AGHA Users
module "foobar" {
  source    = "../../modules/iam_user/default_user"
  username  = "foobar"
  full_name = "Foo X Bar"
  keybase   = "foobarkeybase"
  email     = "foo@bar.com"
}
resource "aws_iam_user_login_profile" "foobar" {
  user    = module.foobar.username
  pgp_key = "keybase:freisinger"
}
################################################################################
# Groups

# Submitters
resource "aws_iam_group" "submitter" {
  name = "agha_gdr_submitters"
  path = "/agha/"
}

################################################################################
# Group memberships

resource "aws_iam_group_membership" "submitter" {
  name  = "${aws_iam_group.submitter.name}_membership"
  group = aws_iam_group.submitter.name
  users = [
    module.foobar.username,
  ]
}

# submitter group policies
resource "aws_iam_group_policy_attachment" "submit_default_user_policy_attachment" {
  group      = aws_iam_group.submitter.name
  policy_arn = aws_iam_policy.default_user_policy.arn
}

resource "aws_iam_group_policy_attachment" "submit_store_rw_policy_attachment" {
  group      = aws_iam_group.submitter.name
  policy_arn = aws_iam_policy.agha_staging_rw_policy.arn
}

resource "aws_iam_group_policy_attachment" "submit_store_ro_policy_attachment" {
  group      = aws_iam_group.submitter.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}

################################################################################
# Create access policies

# data "template_file" "default_user_policy" {
#   template = file("policies/default-user-policy.json")
# }

# data "template_file" "agha_staging_ro_policy" {
#   template = file("policies/bucket-ro-policy.json")

#   vars = {
#     bucket_name = data.aws_s3_bucket.agha_gdr_staging.id
#   }
# }

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
  # policy = data.template_file.default_user_policy.rendered
  policy = file("policies/default-user-policy.json")
}

# resource "aws_iam_policy" "agha_staging_ro_policy" {
#   name   = "agha_staging_ro_policy"
#   path   = "/agha/"
#   policy = data.template_file.agha_staging_ro_policy.rendered
# }

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

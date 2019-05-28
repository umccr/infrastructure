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

resource "aws_s3_bucket" "agha_gdr_staging" {
  bucket = "${var.agha_gdr_staging_bucket_name}"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  tags = "${merge(
    local.common_tags,
    map(
      "Name", "${var.agha_gdr_staging_bucket_name}"
    )
  )}"
}

resource "aws_s3_bucket" "agha_gdr_store" {
  bucket = "${var.agha_gdr_store_bucket_name}"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  tags = "${merge(
    local.common_tags,
    map(
      "Name", "${var.agha_gdr_store_bucket_name}"
    )
  )}"
}

# Attach bucket policy to deny object deletion
# https://aws.amazon.com/blogs/security/how-to-restrict-amazon-s3-bucket-access-to-a-specific-iam-role/

data "template_file" "store_bucket_policy" {
  template = "${file("policies/agha_bucket_policy.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.agha_gdr_store.id}"
    account_id  = "${data.aws_caller_identity.current.account_id}"
    role_id     = "${aws_iam_role.s3_admin_delete.unique_id}"
  }
}

resource "aws_s3_bucket_policy" "store_bucket_policy" {
  bucket = "${aws_s3_bucket.agha_gdr_store.id}"
  policy = "${data.template_file.store_bucket_policy.rendered}"
}

data "template_file" "staging_bucket_policy" {
  template = "${file("policies/agha_bucket_policy.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.agha_gdr_staging.id}"
    account_id  = "${data.aws_caller_identity.current.account_id}"
    role_id     = "${aws_iam_role.s3_admin_delete.unique_id}"
  }
}

resource "aws_s3_bucket_policy" "staging_bucket_policy" {
  bucket = "${aws_s3_bucket.agha_gdr_staging.id}"
  policy = "${data.template_file.staging_bucket_policy.rendered}"
}


################################################################################
# Dedicated IAM role to delete S3 objects (otherwise not allowed)

data "template_file" "saml_assume_policy" {
  template = "${file("policies/assume_role_saml.json")}"

  vars {
    aws_account   = "${data.aws_caller_identity.current.account_id}"
    saml_provider = "${var.saml_provider}"
  }
}

resource "aws_iam_role" "s3_admin_delete" {
  name                 = "s3_admin_delete"
  path                 = "/"
  assume_role_policy   = "${data.template_file.saml_assume_policy.rendered}"
  max_session_duration = "43200"
}

resource "aws_iam_role_policy_attachment" "s3_admin_delete" {
  role       = "${aws_iam_role.s3_admin_delete.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
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
# Dedicated user to list store content

module "agha_catalogue_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "agha_catalogue"
  pgp_key  = "keybase:ametke"
}

resource "aws_iam_user_policy_attachment" "ahga_catalogue_store_list" {
  user       = "${module.agha_catalogue_user.username}"
  policy_arn = "${aws_iam_policy.agha_store_list_policy.arn}"
}


################################################################################
# Users & groups

module "freisinger" {
  source   = "../../modules/iam_user/secure_user"
  username = "freisinger"
  pgp_key  = "keybase:freisinger"
}

module "ametke" {
  source   = "../../modules/iam_user/secure_user"
  username = "ametke"
  pgp_key  = "keybase:ametke"
}

module "simonsadedin" {
  source   = "../../modules/iam_user/secure_user"
  username = "simonsadedin"
  pgp_key  = "keybase:simonsadedin"
}

module "sebastian" {
  source   = "../../modules/iam_user/secure_user"
  username = "sebastian"
  pgp_key  = "keybase:freisinger"
}

module "ebenngarvan" {
  source   = "../../modules/iam_user/secure_user"
  username = "ebenngarvan"
  pgp_key  = "keybase:ebenngarvan"
}

module "michaelblackpath" {
  source   = "../../modules/iam_user/secure_user"
  username = "michaelblackpath"
  pgp_key  = "keybase:michaelblackpath"
}

module "deanmeisong" {
  source   = "../../modules/iam_user/secure_user"
  username = "deanmeisong"
  pgp_key  = "keybase:deanmeisong"
}

module "scottwood" {
  source   = "../../modules/iam_user/secure_user"
  username = "scottwood"
  pgp_key  = "keybase:qimrbscott"
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

resource "aws_iam_group_membership" "admin_members" {
  name  = "${aws_iam_group.admin.name}_membership"
  users = ["${module.freisinger.username}"]
  group = "${aws_iam_group.admin.name}"
}

resource "aws_iam_group_membership" "submit_members" {
  name  = "${aws_iam_group.submit.name}_membership"
  users = ["${module.simonsadedin.username}", "${module.sebastian.username}", "${module.michaelblackpath.username}", "${module.deanmeisong.username}", "${module.scottwood.username}"]
  group = "${aws_iam_group.submit.name}"
}

resource "aws_iam_group_membership" "read_members" {
  name  = "${aws_iam_group.read.name}_membership"
  users = ["${module.ametke.username}", "${module.ebenngarvan.username}"]
  group = "${aws_iam_group.read.name}"
}

################################################################################
# Create access policies

data "template_file" "agha_staging_rw_policy" {
  template = "${file("policies/bucket-rw-policy.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.agha_gdr_staging.id}"
  }
}

data "template_file" "agha_store_ro_policy" {
  template = "${file("policies/bucket-ro-policy.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.agha_gdr_store.id}"
  }
}

data "template_file" "agha_store_rw_policy" {
  template = "${file("policies/bucket-rw-policy.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.agha_gdr_store.id}"
  }
}

data "template_file" "agha_store_list_policy" {
  template = "${file("policies/bucket-list-policy.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.agha_gdr_store.id}"
  }
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



################################################################################
# Slack notification lambda

data "aws_secretsmanager_secret" "slack_webhook_id" {
  name = "slack/webhook/id"
}

data "aws_secretsmanager_secret_version" "slack_webhook_id" {
  secret_id = "${data.aws_secretsmanager_secret.slack_webhook_id.id}"
}

module "notify_slack_lambda" {
  # based on: https://github.com/claranet/terraform-aws-lambda
  source = "../../modules/lambda"

  function_name = "${var.stack_name}_slack_lambda"
  description   = "Lambda to send messages to Slack"
  handler       = "notify_slack.lambda_handler"
  runtime       = "python3.6"
  timeout       = 3

  source_path = "${path.module}/lambdas/notify_slack.py"

  environment {
    variables {
      SLACK_HOST             = "hooks.slack.com"
      SLACK_WEBHOOK_ENDPOINT = "/services/${data.aws_secretsmanager_secret_version.slack_webhook_id.secret_string}"
      SLACK_CHANNEL          = "${var.slack_channel}"
    }
  }

    tags = "${merge(
    local.common_tags,
    map(
      "Description", "Lambda to send notifications to UMCCR Slack"
    )
  )}"
}

################################################################################
# CloudWatch Event Rule to match batch events and call Slack lambda

resource "aws_cloudwatch_event_rule" "batch_failure" {
  name        = "${var.stack_name}_capture_batch_job_failure"
  description = "Capture Batch Job Failures"

  event_pattern = <<PATTERN
{
  "detail-type": [
    "Batch Job State Change"
  ],
  "source": [
    "aws.batch"
  ],
  "detail": {
    "status": [
      "FAILED"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "batch_failure" {
  rule      = "${aws_cloudwatch_event_rule.batch_failure.name}"
  target_id = "${var.stack_name}_send_batch_failure_to_slack_lambda"
  arn       = "${module.notify_slack_lambda.function_arn}"

  input_transformer = {
    input_paths = {
      job    = "$.detail.jobName"
      title  = "$.detail-type"
      status = "$.detail.status"
    }

    # https://serverfault.com/questions/904992/how-to-use-input-transformer-for-cloudwatch-rule-target-ssm-run-command-aws-ru
    input_template = "{ \"topic\": <title>, \"title\": <job>, \"message\": <status> }"
  }
}

resource "aws_lambda_permission" "batch_failure" {
  statement_id  = "${var.stack_name}_allow_batch_failure_to_invoke_slack_lambda"
  action        = "lambda:InvokeFunction"
  function_name = "${module.notify_slack_lambda.function_arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.batch_failure.arn}"
}

# Disable SUCCESS
# resource "aws_cloudwatch_event_rule" "batch_success" {
#   name        = "${var.stack_name}_capture_batch_job_success"
#   description = "Capture Batch Job Success"

#   event_pattern = <<PATTERN
# {
#   "detail-type": [
#     "Batch Job State Change"
#   ],
#   "source": [
#     "aws.batch"
#   ],
#   "detail": {
#     "status": [
#       "SUCCEEDED"
#     ]
#   }
# }
# PATTERN
# }

# resource "aws_cloudwatch_event_target" "batch_success" {
#   rule      = "${aws_cloudwatch_event_rule.batch_success.name}"
#   target_id = "${var.stack_name}_send_batch_success_to_slack_lambda"
#   arn       = "${module.notify_slack_lambda.function_arn}"

#   input_transformer = {
#     input_paths = {
#       job    = "$.detail.jobName"
#       title  = "$.detail-type"
#       status = "$.detail.status"
#     }

#     # https://serverfault.com/questions/904992/how-to-use-input-transformer-for-cloudwatch-rule-target-ssm-run-command-aws-ru
#     input_template = "{ \"topic\": <title>, \"title\": <job>, \"message\": <status> }"
#   }
# }

# resource "aws_lambda_permission" "batch_success" {
#   statement_id  = "${var.stack_name}_allow_batch_success_to_invoke_slack_lambda"
#   action        = "lambda:InvokeFunction"
#   function_name = "${module.notify_slack_lambda.function_arn}"
#   principal     = "events.amazonaws.com"
#   source_arn    = "${aws_cloudwatch_event_rule.batch_success.arn}"
# }

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
# New dataset ready notification (i.e. manifest S3 creation event -> Slack) 


data "aws_sns_topic" "s3_events" {
  name = "s3_manifest_event"
}

resource "aws_sns_topic_subscription" "s3_manifest_event" {
  topic_arn = "${data.aws_sns_topic.s3_events.arn}"
  protocol  = "lambda"
  endpoint  = "${module.notify_slack_lambda.function_arn}"
}

resource "aws_sns_topic_subscription" "s3_manifest_event_folder_lock" {
  topic_arn = "${data.aws_sns_topic.s3_events.arn}"
  protocol  = "lambda"
  endpoint  = "${module.folder_lock_lambda.function_arn}"
}

resource "aws_lambda_permission" "slack_lambda_from_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${module.notify_slack_lambda.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${data.aws_sns_topic.s3_events.arn}"
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



################################################################################
# Lambdas

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

  attach_policy = true
  policy        = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"

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

# Folder lock lambda
data "template_file" "folder_lock_lambda" {
  template = "${file("${path.module}/policies/folder_lock_lambda.json")}"

  vars {
    bucket_name = "${data.aws_s3_bucket.agha_gdr_staging.id}"
  }
}

resource "aws_iam_policy" "folder_lock_lambda" {
  name   = "${var.stack_name}_folder_lock_lambda_${terraform.workspace}"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.folder_lock_lambda.rendered}"
}

module "folder_lock_lambda" {
  # based on: https://github.com/claranet/terraform-aws-lambda
  source = "../../modules/lambda"

  function_name = "${var.stack_name}_folder_lock_lambda"
  description   = "Lambda to update bucket policy to deny put/delete"
  handler       = "folder_lock.lambda_handler"
  runtime       = "python3.7"
  timeout       = 3

  source_path = "${path.module}/lambdas/folder_lock.py"

  attach_policy = true
  policy        = "${aws_iam_policy.folder_lock_lambda.arn}"

  tags = "${merge(
    local.common_tags,
    map(
      "Description", "Lambda to update a bucket policy to Deny PutObject/DeleteObject whenever a specific flag file event was triggered"
    )
  )}"
}

# allow events from SNS topic for manifest notifications
resource "aws_lambda_permission" "folder_lock_sns_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${module.folder_lock_lambda.function_arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${data.aws_sns_topic.s3_events.arn}"
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


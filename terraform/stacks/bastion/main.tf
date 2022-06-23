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
  version = "~> 2.4.0"
  region = "ap-southeast-2"
}

################################################################################
##### create service users

# packer
#module "packer_user" {
#  source   = "../../modules/iam_user/secure_user"
#  username = "packer"
#  pgp_key  = "keybase:freisinger"
#}

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

# User for CloudWatchAgent running on novastor
module "novastor_cloudwatch_user" {
  source   = "../../modules/iam_user/secure_user"
  username = "novastor_cloudwatch"
  pgp_key  = "keybase:freisinger"
}

resource "aws_iam_user_policy_attachment" "novastor_cloudwatch_user_policy_1" {
  user       = "${module.novastor_cloudwatch_user.username}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_user_policy_attachment" "novastor_cloudwatch_user_policy_2" {
  user       = "${module.novastor_cloudwatch_user.username}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

################################################################################
# define the assume role policies and who can use them

# packer_role (on dev)
#data "template_file" "assume_packer_role_policy" {
#  template = "${file("policies/assume_role_no_mfa.json")}"
#
#  vars {
#    role_arn = "arn:aws:iam::620123204273:role/packer_role"
#  }
#}

#resource "aws_iam_policy" "assume_packer_role_policy" {
#  name   = "assume_packer_role_policy"
#  path   = "/"
#  policy = "${data.template_file.assume_packer_role_policy.rendered}"
#}

#resource "aws_iam_policy_attachment" "packer_assume_packer_role_attachment" {
#  name       = "packer_assume_packer_role_attachment"
#  policy_arn = "${aws_iam_policy.assume_packer_role_policy.arn}"
#  groups     = []
#  users      = ["${module.packer_user.username}"]
#  roles      = []
#}

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
  groups     = []
  users      = ["${module.terraform_user.username}"]
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
  groups     = []
  users      = ["${module.terraform_user.username}"]
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
  groups     = []
  users      = ["${module.terraform_user.username}"]
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


## Slack notify Lambda #########################################################

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

  tags = {
    Service     = "${var.stack_name}_lambda"
    Name        = "${var.stack_name}_slack_lambda"
    Stack       = "${var.stack_name}"
    Environment = "prod"
  }
}

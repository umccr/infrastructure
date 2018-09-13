# NOTE: two AWS profiles are used:
# - umccr_ops_admin_no_mfa: admin access to dev account to manage resources
# - umccr_admin_bastion: access to bastion account to create users/groups/etc 
terraform {
  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "agha_gdr/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
    profile        = "umccr_ops_admin_no_mfa"
  }
}

provider "aws" {
  region  = "ap-southeast-2"
  profile = "umccr_ops_admin_no_mfa"
}

provider "aws" {
  alias   = "bastion"
  region  = "ap-southeast-2"
  profile = "umccr_admin_bastion"
}

################################################################################
# users, assume role policies, etc ...
# => bastion account

module "users" {
  providers = {
    aws.account = "aws.bastion"
  }

  source = "../../modules/iam_user/secure_users"
  users  = "${var.agha_users_map}"
}

resource "aws_iam_user_login_profile" "users_login" {
  provider   = "aws.bastion"
  count      = "${length(keys(var.agha_users_map))}"
  user       = "${element(keys(var.agha_users_map), count.index)}"
  pgp_key    = "${element(values(var.agha_users_map), count.index)}"
  depends_on = ["module.users"]
}

resource "aws_iam_group" "group" {
  provider   = "aws.bastion"
  count      = "${length(keys(var.group_members_map))}"
  name       = "${element(keys(var.group_members_map), count.index)}"
  depends_on = ["module.users"]
}

resource "aws_iam_group_membership" "group_members" {
  provider   = "aws.bastion"
  count      = "${length(keys(var.group_members_map))}"
  name       = "${element(keys(var.group_members_map), count.index)}_membership"
  users      = "${var.group_members_map[element(keys(var.group_members_map), count.index)]}"
  group      = "${element(keys(var.group_members_map), count.index)}"
  depends_on = ["aws_iam_group.group"]
}

resource "aws_iam_group_policy" "group_assume_policy" {
  provider   = "aws.bastion"
  count      = "${length(keys(var.group_roles_map))}"
  group      = "${element(keys(var.group_roles_map), count.index)}"
  depends_on = ["aws_iam_group.group"]

  # define which roles the group members can assume
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ "sts:AssumeRole" ],
      "Resource": ${jsonencode(var.group_roles_map[element(keys(var.group_roles_map), count.index)])}
    }
  ]
}
EOF
}

################################################################################
# bucket(s), roles, policies, role - policy attachments, etc ...
# => work account (dev/prod)

resource "aws_s3_bucket" "agha_gdr_staging" {
  bucket = "${var.agha_gdr_staging_bucket_name[terraform.workspace]}"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  logging {
    target_bucket = "${aws_s3_bucket.agha_gdr_log.id}"
    target_prefix = "log/access/staging/"
  }

  tags {
    Name        = "agha-gdr-staging"
    Project     = "AGHA-GDR"
    Environment = "${terraform.workspace}"
  }
}

resource "aws_s3_bucket" "agha_gdr_store" {
  bucket = "${var.agha_gdr_store_bucket_name[terraform.workspace]}"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  logging {
    target_bucket = "${aws_s3_bucket.agha_gdr_log.id}"
    target_prefix = "log/access/store/"
  }

  tags {
    Name        = "agha-gdr-store"
    Project     = "AGHA-GDR"
    Environment = "${terraform.workspace}"
  }
}

resource "aws_s3_bucket" "agha_gdr_log" {
  bucket = "${var.agha_gdr_log_bucket_name[terraform.workspace]}"
  acl    = "log-delivery-write"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags {
    Name        = "agha-gdr-log"
    Project     = "AGHA-GDR"
    Environment = "${terraform.workspace}"
  }
}

resource "aws_iam_role" "agha_member_roles" {
  count                = "${length(keys(var.group_members_map))}"
  name                 = "${element(keys(var.group_members_map), count.index)}"
  path                 = "/"
  assume_role_policy   = "${file("policies/assume-role-from-bastion.json")}"
  max_session_duration = "43200"
}

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

resource "aws_iam_role_policy_attachment" "agha_staging_rw_policy_attachment" {
  count      = "${length(var.agha_staging_rw)}"
  role       = "${var.agha_staging_rw[count.index]}"
  policy_arn = "${aws_iam_policy.agha_staging_rw_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "agha_store_ro_policy_attachment" {
  count      = "${length(var.agha_store_ro)}"
  role       = "${var.agha_store_ro[count.index]}"
  policy_arn = "${aws_iam_policy.agha_store_ro_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "agha_store_rw_policy_attachment" {
  count      = "${length(var.agha_store_rw)}"
  role       = "${var.agha_store_rw[count.index]}"
  policy_arn = "${aws_iam_policy.agha_store_rw_policy.arn}"
}

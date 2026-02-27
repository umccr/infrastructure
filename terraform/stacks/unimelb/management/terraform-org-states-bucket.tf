/**
 * S3 bucket for terraform state
 *
 * This bucket and policy allows sub organisation accounts to read/write terraform
 * state into this central bucket. They are only allowed to operation on a prefix
 * that matches their account id.
 *
 * This is all in aid of not needing to bootstrap each research account
 * before we use terraform in it. Terraform can be used immediately in each account (assuming the account
 * is registered in our master account list here)
 */

resource "aws_s3_bucket" "terraform_org_states" {
  bucket = "terraform-org-states-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
}

# allow us to rollback to previous states
resource "aws_s3_bucket_versioning" "terraform_org_states" {
  bucket = aws_s3_bucket.terraform_org_states.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "terraform_org_states" {
  bucket = aws_s3_bucket.terraform_org_states.id
  policy = data.aws_iam_policy_document.terraform_org_states.json
}

data "aws_iam_policy_document" "terraform_org_states" {
  statement {
    sid     = "AllowAccountScopedList"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.terraform_org_states.arn]

    # restrict to our known accounts
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = local.account_id_list_without_management_account
    }

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["$${aws:PrincipalAccount}/*"]
    }

    # restrict to admin principals
    condition {
      variable = "aws:PrincipalArn"
      test     = "StringLike"
      values   = local.terraform_allowed_roles
    }
  }

  statement {
    sid     = "AllowAccountScopedReadWrite"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = ["${aws_s3_bucket.terraform_org_states.arn}/$${aws:PrincipalAccount}/*"]

    # restrict to our known accounts
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = local.account_id_list_without_management_account
    }

    # restrict to admin principals
    condition {
      variable = "aws:PrincipalArn"
      test     = "StringLike"
      values   = local.terraform_allowed_roles
    }
  }
}

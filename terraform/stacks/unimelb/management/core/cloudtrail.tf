# TODO: create CloudTrail bucket
resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.cloudtrail_bucket_name

  tags = {
    "Name" = local.cloudtrail_bucket_name
  }
}

# bucket policy to allow other UoM accounts trails to log to this bucket
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail.json
}

# From: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-set-bucket-policy-for-multiple-accounts.html
data "aws_iam_policy_document" "cloudtrail" {
  statement {
    sid = "CloudTrailAclCheck"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
    ]
    resources = [
      aws_s3_bucket.cloudtrail.arn,
    ]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceArn"
      values = [
        for k, v in var.member_accounts :
        "arn:aws:cloudtrail:${local.region}:${v.account_id}:trail/${v.cloudtrail_trail}"
        if v.cloudtrail_trail != null
      ]
    }
  }
  statement {
    sid = "CloudTrailWrite"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      for k, v in var.member_accounts :
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${v.account_id}/*"
      if v.cloudtrail_trail != null
    ]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceArn"
      values = [
        for k, v in var.member_accounts :
        "arn:aws:cloudtrail:${local.region}:${v.account_id}:trail/${v.cloudtrail_trail}"
        if v.cloudtrail_trail != null
      ]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "bucket-owner-full-control"
      ]
    }
  }
}

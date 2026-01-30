
data "aws_iam_policy_document" "require_imds_v2" {
  statement {
    effect = "Deny"

    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringNotEquals"
      variable = "ec2:MetadataHttpTokens"
      values   = ["required"]
    }
  }
}

resource "aws_organizations_policy" "require_imds_v2" {
  name    = "RequireIMDSv2"
  type    = "SERVICE_CONTROL_POLICY"
  content = data.aws_iam_policy_document.require_imds_v2.json
  description = "[EC2.8] EC2 instances should use Instance Metadata Service Version 2 (IMDSv2) See: https://docs.aws.amazon.com/securityhub/latest/userguide/ec2-controls.html#ec2-8"
}

resource "aws_organizations_policy_attachment" "require_imds_v2_on_random" {
  policy_id = aws_organizations_policy.require_imds_v2.id
  target_id = data.aws_organizations_organizational_unit.development_ou.id
}

output "cloudtrail_bucket_name" {
  description = "Name of the centralised CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_bucket_arn" {
  description = "ARN of the centralised CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "member_accounts" {
  description = "Member account registry as supplied via accounts.tfvars"
  value       = var.member_accounts
}

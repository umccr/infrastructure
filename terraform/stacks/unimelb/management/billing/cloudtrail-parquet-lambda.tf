/**
 * Deploy a lambda that converts CloudTrail to Parquet
 */

module "cloudtrail_parquet_lambda" {
  source = "../../../../modules/cloudtrail_parquet_lambda"

  name       = "cloudtrail-parquet-lambda"
  aws_region = data.aws_region.current.id

  ghcr_repo = "ghcr.io/umccr/cloudtrail-parquet-lambda"
  ghcr_tag  = "2.0.0"

  cloudtrail_base_input_path  = "s3://${local.cloudtrail_bucket_name}/"
  cloudtrail_base_output_path = "s3://${local.cloudtrail_bucket_name}/"
  # organisation_id             No organisation structure for unimelb
  account_ids = [
    for k, v in var.member_accounts : v.account_id
    if v.cloudtrail_trail != null
  ]
}

/**
 * Deploy a lambda that converts CloudTrail to Parquet
 */

module "cloudtrail_parquet_lambda" {
  source = "../../../modules/cloudtrail_parquet_lambda"

  name       = "cloudtrail-parquet-lambda"
  aws_region = data.aws_region.current.id

  ghcr_repo = "ghcr.io/umccr/cloudtrail-parquet-lambda"
  ghcr_tag  = "1.0.0"

  cloudtrail_base_input_path  = "s3://${aws_s3_bucket.cloudtrail_root.id}/"
  cloudtrail_base_output_path = "s3://${aws_s3_bucket.cloudtrail_root.id}/"

  organisation_id = "o-p5xvdd9ddb"

  # trialing on these accounts
  account_ids = concat(
    local.development_account_ids,
    local.operational_account_ids,
    local.production_account_ids
  )
}

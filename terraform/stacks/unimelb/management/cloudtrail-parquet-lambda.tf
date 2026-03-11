/**
 * Deploy a lambda that converts CloudTrail to Parquet
 */

data "aws_ecr_authorization_token" "this" {}

provider "docker" {
  registry_auth {
    address  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com"
    username = "AWS"
    password = data.aws_ecr_authorization_token.this.password
  }
}

module "cloudtrail_parquet_lambda" {
  source = "../../../modules/cloudtrail_parquet_lambda"

  name       = "cloudtrail-parquet-lambda"
  aws_region = data.aws_region.current.id

  ghcr_repo = "ghcr.io/umccr/cloudtrail-parquet-lambda"
  ghcr_tag  = "sha-163fa2d"

  cloudtrail_base_input_path  = "s3://${aws_s3_bucket.cloudtrail.id}/"
  cloudtrail_base_output_path = "s3://${aws_s3_bucket.cloudtrail.id}/"
  # organisation_id             No organisation structure for unimelb
  account_ids = [
    "503977275616",
    "977251586657"
  ]
}

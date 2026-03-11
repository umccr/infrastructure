# CloudTrail Parquet Lambda module

A terraform module to deploy a lambda function that
converts CloudTrail events to Parquet format and stores them in S3.

## Usage

```terraform
module "cloudtrail_parquet_lambda" {
  source = "<path to this>/modules/cloudtrail_parquet_lambda"

  name       = "cloudtrail-parquet-lambda"
  aws_region = data.aws_region.current.id

  ghcr_repo = "ghcr.io/umccr/cloudtrail-parquet-lambda"
  ghcr_tag  = "sha-7a64c06"

  cloudtrail_base_input_path  = "s3://${aws_s3_bucket.cloudtrail_root.id}/"
  cloudtrail_base_output_path = "s3://${aws_s3_bucket.cloudtrail_root.id}/"
  organisation_id             = "o-abcdefghi"
  account_ids                 =  ["1234567890", "0123456789"]
}
```

/**
 * A lambda function to process CloudTrail logs and write them to S3 in Parquet format
 */

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_s3" {
  statement {
    sid     = "ReadCloudTrailLogs"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${split("/", split("s3://", var.cloudtrail_base_input_path)[1])[0]}",
      "arn:aws:s3:::${split("/", split("s3://", var.cloudtrail_base_input_path)[1])[0]}/*",
    ]
  }

  statement {
    sid     = "WriteParquetOutput"
    actions = ["s3:PutObject", "s3:AbortMultipartUpload"]
    resources = [
      "arn:aws:s3:::${split("/", split("s3://", var.cloudtrail_base_output_path)[1])[0]}/*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda_s3" {
  name   = "s3-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_s3.json
}

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = local.ecr_image_uri
  architectures = ["arm64"]

  # some sensible defaults (give the lambda as much time as possible
  # to process the entire account), and give it plenty of memory (actual
  # mem usage is about 1 Gib and should be roughly constant irrespective of
  # the amount of entries)
  timeout       = 15*60
  memory_size   = 3000

  depends_on = [
    aws_iam_role_policy_attachment.basic_execution,
    aws_cloudwatch_log_group.lambda,
    docker_registry_image.ecr,
  ]
}

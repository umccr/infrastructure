locals {
  secret_name_prefix = "data_portal/rds/master"
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "athena_jdbc_connector" {
  # See https://serverlessrepo.aws.amazon.com/applications/us-east-1/292517598671/AthenaJdbcConnector
  name             = "AthenaJdbcConnector"
  application_id   = "arn:aws:serverlessrepo:us-east-1:292517598671:applications/AthenaJdbcConnector"
  semantic_version = "2022.4.1"

  capabilities = [
    "CAPABILITY_IAM",
  ]

  parameters = {
    # The default connection string is used when catalog is "lambda:${LambdaFunctionName}". Catalog specific Connection Strings can be added later. Format: ${DatabaseType}://${NativeJdbcConnectionString}.
    DefaultConnectionString = "mysql://jdbc:mysql://${aws_rds_cluster.db.endpoint}:${aws_rds_cluster.db.port}/${aws_rds_cluster.db.database_name}?$${${local.secret_name_prefix}}"
    # If set to 'false' data spilled to S3 is encrypted with AES GCM. Default is 'false'
    # DisableSpillEncryption  = "true"
    # The name you will give to this catalog in Athena. It will also be used as the function name. This name must satisfy the pattern ^[a-z0-9-_]{1,64}$
    LambdaFunctionName      = local.stack_name_us
    # Lambda memory in MB (min 128 - 3008 max).
    # LambdaMemory            = "128"
    # Maximum Lambda invocation runtime in seconds. (min 1 - 900 max)
    # LambdaTimeout           = "120"
    # Used to create resource-based authorization policy for "secretsmanager:GetSecretValue" action. E.g. All Athena JDBC Federation secret names can be prefixed with "AthenaJdbcFederation" and authorization policy will allow "arn:${AWS::Partition}:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:AthenaJdbcFederation*". Parameter value in this case should be "AthenaJdbcFederation". If you do not have a prefix, you can manually update the IAM policy to add allow any secret names.
    SecretNamePrefix        = local.secret_name_prefix
    # One or more SecurityGroup IDs corresponding to the SecurityGroup that should be applied to the Lambda function. (e.g. sg1,sg2,sg3)
    SecurityGroupIds        = aws_security_group.lambda_security_group.id
    # The name of the bucket where this function can spill data.
    SpillBucket             = aws_s3_bucket.codepipeline_bucket.bucket
    # The prefix within SpillBucket where this function can spill data.
    SpillPrefix             = "AthenaJdbcConnector"
    # One or more Subnet IDs corresponding to the Subnet that the Lambda function can use to access you data source. (e.g. subnet1,subnet2)
    SubnetIds               = join(",", data.aws_subnets.private_subnets_ids.ids)
  }

  tags = merge(local.default_tags)
}

resource "aws_athena_workgroup" "data_portal" {
  name        = local.stack_name_us
  description = "${local.stack_name_us} Athena Workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.codepipeline_bucket.bucket}/athena-query-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = merge(local.default_tags)
}

resource "aws_athena_data_catalog" "data_portal" {
  name        = local.stack_name_us
  description = "${local.stack_name_us} Athena Data Catalog"
  type        = "LAMBDA"

  parameters = {
    "function" = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.stack_name_us}"
  }

  tags = merge(local.default_tags)
}

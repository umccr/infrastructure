################################################################################
# Back end configurations

data "aws_acm_certificate" "backend_cert2" {
  domain   = local.app_domain2
  statuses = ["ISSUED"]
}

################################################################################
# Lambda execution role for API backend

resource "aws_iam_role" "lambda_apis_role" {
  name = "${local.stack_name_us}_lambda_apis_role"
  path = local.iam_role_path

  # Setting 12 hour so presigned URL generated (by the lambda) could live up to this max duration
  max_session_duration = 43200

  # IAM role for lambda functions (to be use by Serverless framework)
  assume_role_policy = templatefile("policies/lambda_apis_role_assume_role_policy.json", {})

  tags = merge(local.default_tags)
}

resource "aws_iam_role_policy" "lambda_apis_role_policy" {
  name = "${local.stack_name_us}_lambda_apis_policy"
  role = aws_iam_role.lambda_apis_role.id

  policy = templatefile("policies/lambda_apis_policy.json", {})
}

################################################################################
# Security group configurations

# Security group for lambda functions
resource "aws_security_group" "lambda_security_group" {
  vpc_id      = data.aws_vpc.main_vpc.id
  name        = "${local.stack_name_us}_lambda"
  description = "Security group for lambda functions"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags)
}

# Use a separate security group for CodeBuild for apis
resource "aws_security_group" "codebuild_apis_security_group" {
  vpc_id      = data.aws_vpc.main_vpc.id
  name        = "${local.stack_name_us}_codebuild_apis"
  description = "Security group for codebuild for backend (apis)"

  # No ingress traffic allowed to your builds
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags)
}

# Security group for RDS
resource "aws_security_group" "rds_security_group" {
  vpc_id      = data.aws_vpc.main_vpc.id
  name        = "${local.stack_name_us}_rds"
  description = "Allow inbound traffic for RDS MySQL"

  # Allow access from lambda functions and codebuild for apis
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"

    # Allowing both lambda functions and codebuild (integration tests) to access RDS
    security_groups = [
      aws_security_group.lambda_security_group.id,
      aws_security_group.codebuild_apis_security_group.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags)
}

################################################################################
# Save configurations in SSM Parameter Store
# TODO: this could improve by using AWS Cloud Map resource discovery service instead

# Save these in SSM Parameter Store for backend api

resource "aws_ssm_parameter" "lambda_iam_role_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/lambda_iam_role_arn"
  type  = "String"
  value = aws_iam_role.lambda_apis_role.arn
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "lambda_subnet_ids" {
  name  = "${local.ssm_param_key_backend_prefix}/lambda_subnet_ids"
  type  = "String"
  value = join(",", data.aws_subnets.private_subnets_ids.ids)
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "lambda_security_group_ids" {
  name  = "${local.ssm_param_key_backend_prefix}/lambda_security_group_ids"
  type  = "String"
  value = aws_security_group.lambda_security_group.id
  tags  = merge(local.default_tags)
}

# retain ssm param for backward compatibility and point to newer Portal domain
resource "aws_ssm_parameter" "api_domain_name" {
  name  = "${local.ssm_param_key_backend_prefix}/api_domain_name"
  type  = "String"
  value = local.api_domain2
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "api_domain_name2" {
  name  = "${local.ssm_param_key_backend_prefix}/api_domain_name2"
  type  = "String"
  value = local.api_domain2
  tags  = merge(local.default_tags)
}

# retain ssm param for backward compatibility and point to newer Portal domain SSL cert
resource "aws_ssm_parameter" "certificate_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/certificate_arn"
  type  = "String"
  value = data.aws_acm_certificate.backend_cert2.arn
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "certificate_arn2" {
  name  = "${local.ssm_param_key_backend_prefix}/certificate_arn2"
  type  = "String"
  value = data.aws_acm_certificate.backend_cert2.arn
  tags  = merge(local.default_tags)
}

//resource "aws_ssm_parameter" "waf_name" {
//  name  = "${local.ssm_param_key_backend_prefix}/waf_name"
//  type  = "String"
//  value = aws_wafregional_web_acl.api_web_acl.name
//  tags  = merge(local.default_tags)
//}

resource "aws_ssm_parameter" "serverless_deployment_bucket" {
  name  = "${local.ssm_param_key_backend_prefix}/serverless_deployment_bucket"
  type  = "String"
  value = aws_s3_bucket.codepipeline_bucket.bucket
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "slack_channel" {
  name  = "${local.ssm_param_key_backend_prefix}/slack_channel"
  type  = "String"
  value = var.slack_channel[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "serverless_stage" {
  name  = "${local.ssm_param_key_backend_prefix}/stage"
  type  = "String"
  value = terraform.workspace
  tags  = merge(local.default_tags)
}

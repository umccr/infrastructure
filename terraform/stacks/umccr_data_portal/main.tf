terraform {
  required_version = ">= 1.2.1"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_data_portal/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16.0"
    }
  }
}

################################################################################
# Generic resources

provider "aws" {
  region = "ap-southeast-2"
}

# for ACM certificate
provider "aws" {
  region = "us-east-1"
  alias  = "use1"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  # Stack name in underscore
  stack_name_us = "data_portal"

  # Stack name in dash
  stack_name_dash = "data-portal"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }

  client_s3_origin_id           = "clientS3"
  data_portal_domain_prefix     = "data"

  codebuild_project_name_client = "data-portal-client-${terraform.workspace}"
  codebuild_project_name_apis   = "data-portal-apis-${terraform.workspace}"

  api_domain    = "api.${local.app_domain}"
  iam_role_path = "/${local.stack_name_us}/"

  ssm_param_key_client_prefix = "/${local.stack_name_us}/client"
  ssm_param_key_backend_prefix = "/${local.stack_name_us}/backend"

  app_domain = "${local.data_portal_domain_prefix}.${var.base_domain[terraform.workspace]}"

  cert_subject_alt_names = {
    prod = sort(["*.${local.app_domain}", var.alias_domain[terraform.workspace]])
    dev  = sort(["*.${local.app_domain}"])
  }

  cloudfront_domain_aliases = {
    prod = [local.app_domain, var.alias_domain[terraform.workspace]]
    dev  = [local.app_domain]
  }

  callback_urls = {
    prod = ["https://${local.app_domain}", "https://${var.alias_domain[terraform.workspace]}"]
    dev  = ["https://${local.app_domain}"]
  }

  oauth_redirect_url = {
    prod = "https://${var.alias_domain[terraform.workspace]}"
    dev  = "https://${local.app_domain}"
  }

  org_name = "umccr"

  github_repo_client = "data-portal-client"
  github_repo_apis   = "data-portal-apis"
}

################################################################################
# Query for Pre-configured SSM Parameter Store
# These are pre-populated outside of terraform i.e. manually using Console or CLI

data "aws_ssm_parameter" "rds_db_password" {
  name = "/${local.stack_name_us}/${terraform.workspace}/rds_db_password"
}

data "aws_ssm_parameter" "rds_db_username" {
  name = "/${local.stack_name_us}/${terraform.workspace}/rds_db_username"
}

################################################################################
# Query Main VPC configurations from networking stack

data "aws_vpc" "main_vpc" {
  # Using tags filter on networking stack to get main-vpc
  tags = {
    Name        = "main-vpc"
    Stack       = "networking"
    Environment = terraform.workspace
  }
}

data "aws_subnets" "public_subnets_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Tier = "public"
  }
}

data "aws_subnets" "private_subnets_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Tier = "private"
  }
}

data "aws_subnets" "database_subnets_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Tier = "database"
  }
}

################################################################################
# Client configurations

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "client_bucket" {
  bucket = "${local.org_name}-${local.stack_name_dash}-client-${terraform.workspace}"
  tags = merge(local.default_tags)
}

resource "aws_s3_bucket_acl" "client_bucket" {
  bucket = aws_s3_bucket.client_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "client_bucket" {
  bucket = aws_s3_bucket.client_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_website_configuration" "client_bucket" {
  bucket = aws_s3_bucket.client_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Attach the policy to the client bucket
resource "aws_s3_bucket_policy" "client_bucket_policy" {
  bucket = aws_s3_bucket.client_bucket.id

  # Policy document for the client bucket
  policy = templatefile("policies/client_bucket_policy.json", {
    client_bucket_arn          = aws_s3_bucket.client_bucket.arn
    origin_access_identity_arn = aws_cloudfront_origin_access_identity.client_origin_access_identity.iam_arn
  })
}

# Origin access identity for cloudfront to access client s3 bucket
resource "aws_cloudfront_origin_access_identity" "client_origin_access_identity" {
  comment = "Origin access identity for client bucket"
}

# CloudFront layer for client S3 bucket access
resource "aws_cloudfront_distribution" "client_distribution" {
  origin {
    domain_name = aws_s3_bucket.client_bucket.bucket_regional_domain_name
    origin_id   = local.client_s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.client_origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  aliases             = local.cloudfront_domain_aliases[terraform.workspace]
  default_root_object = "index.html"

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.client_cert.arn
    ssl_support_method  = "sni-only"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.client_s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Route handling for SPA
  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  tags = merge(local.default_tags)
}

# Hosted zone for organisation domain
data "aws_route53_zone" "org_zone" {
  name = "${var.base_domain[terraform.workspace]}."
}

# Alias the client domain name to CloudFront distribution address
resource "aws_route53_record" "client_alias" {
  zone_id = data.aws_route53_zone.org_zone.zone_id
  name    = "${local.app_domain}."
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.client_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.client_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Client certificate validation through a Route53 record
resource "aws_route53_record" "client_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.client_cert.domain_validation_options: dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = 60
  zone_id         = data.aws_route53_zone.org_zone.zone_id
}

# The certificate for client domain, validating using DNS
resource "aws_acm_certificate" "client_cert" {
  # Certificate needs to be US Virginia region in order to be used by cloudfront distribution
  provider          = aws.use1
  domain_name       = local.app_domain
  validation_method = "DNS"

  subject_alternative_names = local.cert_subject_alt_names[terraform.workspace]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags)
}

# Optional automatic certificate validation
# If count = 0, cert will be just created and pending validation
# Visit ACM Console UI and follow up to populate validation records in respective Route53 zones
# See var.certificate_validation note
resource "aws_acm_certificate_validation" "client_cert_dns" {
  count = var.certificate_validation[terraform.workspace]

  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.client_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.client_cert_validation : record.fqdn]

  depends_on = [aws_route53_record.client_cert_validation]
}

################################################################################
# Back end configurations

data "aws_acm_certificate" "backend_cert" {
  domain   = local.app_domain
  statuses = ["ISSUED"]
}

################################################################################
# Lambda execution role for API backend

resource "aws_iam_role" "lambda_apis_role" {
  name = "${local.stack_name_us}_lambda_apis_role"
  path = local.iam_role_path

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
# RDS DB configurations

resource "aws_db_subnet_group" "rds" {
  name = "${local.stack_name_us}_db_subnet_group"
  subnet_ids = data.aws_subnets.database_subnets_ids.ids
  tags = merge(local.default_tags)
}

resource "aws_rds_cluster_parameter_group" "db_parameter_group" {
  name        = "${local.stack_name_dash}-db-parameter-group"
  family      = "aurora-mysql8.0"
  description = "${local.stack_name_us} RDS Aurora cluster parameter group"

  parameter {
    # Set to max 1GB. See https://dev.mysql.com/doc/refman/8.0/en/packet-too-large.html
    name  = "max_allowed_packet"
    value = 1073741824
  }

  parameter {
    # Set to 3x. See https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_net_read_timeout
    name  = "net_read_timeout"
    value = 30 * 3  # 30s (default) * 3
  }

  parameter {
    # Set to 3x. See https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_net_write_timeout
    name  = "net_write_timeout"
    value = 60 * 3  # 60s (default) * 3
  }

  tags = merge(local.default_tags)
}

resource "aws_rds_cluster" "db" {
  cluster_identifier  = "${local.stack_name_dash}-aurora-cluster"
  # Engine & Mode. See https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_DescribeDBEngineVersions.html
  engine              = "aurora-mysql"
  engine_mode         = "provisioned"
  engine_version      = "8.0.mysql_aurora.3.02.0"
  skip_final_snapshot = true

  database_name   = local.stack_name_us
  master_username = data.aws_ssm_parameter.rds_db_username.value
  master_password = data.aws_ssm_parameter.rds_db_password.value

  vpc_security_group_ids = [aws_security_group.rds_security_group.id]

  db_subnet_group_name = aws_db_subnet_group.rds.name

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db_parameter_group.name

  serverlessv2_scaling_configuration {
    # See https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-administration.html
    min_capacity = var.rds_min_capacity[terraform.workspace]
    max_capacity = var.rds_max_capacity[terraform.workspace]
  }

  backup_retention_period = var.rds_backup_retention_period[terraform.workspace]

  deletion_protection = true
  storage_encrypted   = true

  tags = merge(local.default_tags)
}

resource "aws_rds_cluster_instance" "db_instance" {
  cluster_identifier = aws_rds_cluster.db.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.db.engine
  engine_version     = aws_rds_cluster.db.engine_version

  db_subnet_group_name = aws_rds_cluster.db.db_subnet_group_name
  publicly_accessible  = false

  tags = merge(local.default_tags)
}

# Composed database url for backend to use
resource "aws_ssm_parameter" "ssm_full_db_url" {
  name        = "${local.ssm_param_key_backend_prefix}/full_db_url"
  type        = "SecureString"
  description = "Database url used by the Django app"
  value       = "mysql://${data.aws_ssm_parameter.rds_db_username.value}:${data.aws_ssm_parameter.rds_db_password.value}@${aws_rds_cluster.db.endpoint}:${aws_rds_cluster.db.port}/${aws_rds_cluster.db.database_name}"

  tags = merge(local.default_tags)
}

################################################################################
# AWS Backup configuration for Aurora DB

data "aws_kms_key" "backup" {
  key_id = "alias/aws/backup"
}

resource "aws_iam_role" "db_backup_role" {
  count              = var.create_aws_backup[terraform.workspace]
  name               = "${local.stack_name_us}_backup_role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["backup.amazonaws.com"]
      }
    }
  ]
}
POLICY

  tags = merge(local.default_tags)
}

resource "aws_iam_role_policy_attachment" "db_backup_role_policy" {
  count      = var.create_aws_backup[terraform.workspace]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.db_backup_role[count.index].name
}

resource "aws_iam_role_policy_attachment" "db_backup_role_restore_policy" {
  count      = var.create_aws_backup[terraform.workspace]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.db_backup_role[count.index].name
}

resource "aws_backup_vault" "db_backup_vault" {
  count = var.create_aws_backup[terraform.workspace]
  name  = "${local.stack_name_us}_backup_vault"
  kms_key_arn = data.aws_kms_key.backup.arn
  tags  = merge(local.default_tags)
}

resource "aws_backup_plan" "db_backup_plan" {
  count = var.create_aws_backup[terraform.workspace]
  name  = "${local.stack_name_us}_backup_plan"

  // Backup weekly and keep it for 6 weeks
  // Cron At 17:00 on every Sunday UTC = AEST/AEDT 3AM/4AM on every Monday
  rule {
    rule_name         = "Weekly"
    target_vault_name = aws_backup_vault.db_backup_vault[count.index].name
    schedule          = "cron(0 17 ? * SUN *)"

    lifecycle {
      delete_after = 42
    }
  }

  tags = merge(local.default_tags)
}

resource "aws_backup_selection" "db_backup" {
  count        = var.create_aws_backup[terraform.workspace]
  name         = "${local.stack_name_us}_backup"
  plan_id      = aws_backup_plan.db_backup_plan[count.index].id
  iam_role_arn = aws_iam_role.db_backup_role[count.index].arn

  resources = [
    aws_rds_cluster.db.arn,
  ]
}

################################################################################
# Web Security configurations

# APIGateway v2 HttpApi does not support AWS WAF. See
# https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html
# Our Portal API endpoints are all secured endpoints and enforced CORS/CSRF origins protection anyway.
# Disabled WAF resources for now, until AWS support this.

# Web Application Firewall for APIs
//resource "aws_wafregional_web_acl" "api_web_acl" {
//  depends_on = [
//    aws_wafregional_sql_injection_match_set.sql_injection_match_set,
//    aws_wafregional_rule.api_waf_sql_rule,
//  ]
//
//  name        = "dataPortalAPIWebAcl"
//  metric_name = "dataPortalAPIWebAcl"
//
//  default_action {
//    type = "ALLOW"
//  }
//
//  rule {
//    action {
//      type = "BLOCK"
//    }
//
//    priority = 1
//    rule_id  = aws_wafregional_rule.api_waf_sql_rule.id
//    type     = "REGULAR"
//  }
//
//  tags = merge(local.default_tags)
//}

# SQL Injection protection
//resource "aws_wafregional_rule" "api_waf_sql_rule" {
//  depends_on  = [aws_wafregional_sql_injection_match_set.sql_injection_match_set]
//  name        = "${local.stack_name_dash}-sql-rule"
//  metric_name = "dataPortalSqlRule"
//
//  predicate {
//    data_id = aws_wafregional_sql_injection_match_set.sql_injection_match_set.id
//    negated = false
//    type    = "SqlInjectionMatch"
//  }
//
//  tags = merge(local.default_tags)
//}

# SQL injection match set
//resource "aws_wafregional_sql_injection_match_set" "sql_injection_match_set" {
//  name = "${local.stack_name_dash}-api-injection-match-set"
//
//  # Based on the suggestion from
//  # https://d0.awsstatic.com/whitepapers/Security/aws-waf-owasp.pdf
//  sql_injection_match_tuple {
//    text_transformation = "HTML_ENTITY_DECODE"
//
//    field_to_match {
//      type = "QUERY_STRING"
//    }
//  }
//
//  sql_injection_match_tuple {
//    text_transformation = "URL_DECODE"
//
//    field_to_match {
//      type = "QUERY_STRING"
//    }
//  }
//}

####################################################################################
# Notification: CloudWatch alarms send through SNS topic to ChatBot to Slack #data-portal channel

resource "aws_sns_topic" "portal_ops_sns_topic" {
  name = "DataPortalTopic"
  display_name = "Data Portal related topics"
  tags = merge(local.default_tags)
}

data "aws_iam_policy_document" "portal_ops_sns_topic_policy_doc" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
      "SNS:Receive",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [aws_sns_topic.portal_ops_sns_topic.arn]

    sid = "__default_statement_ID"
  }

  statement {
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["codestar-notifications.amazonaws.com"]
    }

    resources = [aws_sns_topic.portal_ops_sns_topic.arn]
  }
}

resource "aws_sns_topic_policy" "portal_ops_sns_topic_access_policy" {
  arn    = aws_sns_topic.portal_ops_sns_topic.arn
  policy = data.aws_iam_policy_document.portal_ops_sns_topic_policy_doc.json
}

################################################################################
# Save configurations in SSM Parameter Store

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

resource "aws_ssm_parameter" "api_domain_name" {
  name  = "${local.ssm_param_key_backend_prefix}/api_domain_name"
  type  = "String"
  value = local.api_domain
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "certificate_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/certificate_arn"
  type  = "String"
  value = data.aws_acm_certificate.backend_cert.arn
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

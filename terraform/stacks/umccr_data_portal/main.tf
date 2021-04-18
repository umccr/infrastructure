terraform {
  required_version = ">= 0.14"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_data_portal/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "~> 3.7.0"
      source = "hashicorp/aws"
    }

    github = {
      version = "~> 3.0.0"
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

provider "github" {
  organization = "umccr"
  token        = data.external.get_gh_token_from_ssm.result.gh_token
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  # Stack name in under socre
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

data "external" "get_gh_token_from_ssm" {
  program = ["${path.module}/scripts/get_gh_token_from_ssm.sh"]
  query = {
    # reusing the PAT token, but could use dedicated token with narrow scope
    ssm_param_name = "/${local.stack_name_us}/github/pat_oauth_token"
  }
}

################################################################################
# Query for Pre-configured SSM Parameter Store
# These are pre-populated outside of terraform i.e. manually using Console or CLI

data "aws_ssm_parameter" "github_pat_oauth_token" {
  # Note that OAuthToken = PAT, generated using https://github.com/settings/tokens
  name = "/${local.stack_name_us}/github/pat_oauth_token"
}

data "aws_ssm_parameter" "github_codepipeline_share_token" {
  name = "/${local.stack_name_us}/github/codepipeline_share_token"
}

data "aws_ssm_parameter" "google_oauth_client_id" {
  name  = "/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_id"
}

data "aws_ssm_parameter" "google_oauth_client_secret" {
  name  = "/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_secret"
}

data "aws_ssm_parameter" "rds_db_password" {
  name = "/${local.stack_name_us}/${terraform.workspace}/rds_db_password"
}

data "aws_ssm_parameter" "rds_db_username" {
  name = "/${local.stack_name_us}/${terraform.workspace}/rds_db_username"
}

data "aws_ssm_parameter" "htsget_domain" {
  name = "/htsget/domain"
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

data "aws_subnet_ids" "public_subnets_ids" {
  vpc_id = data.aws_vpc.main_vpc.id

  tags = {
    Tier = "public"
  }
}

data "aws_subnet_ids" "private_subnets_ids" {
  vpc_id = data.aws_vpc.main_vpc.id

  tags = {
    Tier = "private"
  }
}

data "aws_subnet_ids" "database_subnets_ids" {
  vpc_id = data.aws_vpc.main_vpc.id

  tags = {
    Tier = "database"
  }
}

################################################################################
# Client configurations

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "client_bucket" {
  bucket = "${local.org_name}-${local.stack_name_dash}-client-${terraform.workspace}"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = merge(local.default_tags)
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

data "aws_s3_bucket" "s3_primary_data_bucket" {
  bucket = var.s3_primary_data_bucket[terraform.workspace]
}

data "aws_s3_bucket" "s3_run_data_bucket" {
  bucket = var.s3_run_data_bucket[terraform.workspace]
}

resource "aws_sqs_queue" "germline_queue" {
  name = "${local.stack_name_dash}-germline-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "tn_queue" {
  name = "${local.stack_name_dash}-tn-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "notification_queue" {
  name = "${local.stack_name_dash}-notification-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  delay_seconds = 5
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "iap_ens_event_dlq" {
  name = "${local.stack_name_dash}-${terraform.workspace}-iap-ens-event-dlq"
  message_retention_seconds = 1209600
  tags = merge(local.default_tags)
}

# SQS Queue for IAP Event Notification Service event delivery
# See https://iap-docs.readme.io/docs/ens_create-an-amazon-sqs-queue
resource "aws_sqs_queue" "iap_ens_event_queue" {
  name = "${local.stack_name_dash}-${terraform.workspace}-iap-ens-event-queue"
  policy = templatefile("policies/sqs_iap_ens_event_policy.json", {
    # Use the same name as above, if referring there will be circular dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-${terraform.workspace}-iap-ens-event-queue"
  })
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.iap_ens_event_dlq.arn
    maxReceiveCount = 3
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6

  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "report_event_dlq" {
  name = "${local.stack_name_dash}-report-event-dlq"
  message_retention_seconds = 1209600
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "report_event_queue" {
  name = "${local.stack_name_dash}-report-event-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.report_event_dlq.arn
    maxReceiveCount = 20
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6

  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "s3_event_dlq" {
  name = "${local.stack_name_dash}-${terraform.workspace}-s3-event-dlq"
  message_retention_seconds = 1209600
  tags = merge(local.default_tags)
}

# SQS Queue for S3 event delivery
resource "aws_sqs_queue" "s3_event_queue" {
  name = "${local.stack_name_dash}-${terraform.workspace}-s3-event-queue"
  policy = templatefile("policies/sqs_s3_primary_data_event_policy.json", {
    # Use the same name as above, if referring there will be circular dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-${terraform.workspace}-s3-event-queue"
    s3_primary_data_bucket_arn = data.aws_s3_bucket.s3_primary_data_bucket.arn
    s3_run_data_bucket_arn = data.aws_s3_bucket.s3_run_data_bucket.arn
  })
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.s3_event_dlq.arn
    maxReceiveCount = 20
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6

  tags = merge(local.default_tags)
}

# Enable primary data bucket s3 event notification to SQS
resource "aws_s3_bucket_notification" "primary_data_notification" {
  bucket = data.aws_s3_bucket.s3_primary_data_bucket.id

  queue {
    queue_arn = aws_sqs_queue.s3_event_queue.arn

    events = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*",
    ]
  }
}

# Enable run data bucket s3 event notification to SQS
resource "aws_s3_bucket_notification" "run_data_notification" {
  bucket = data.aws_s3_bucket.s3_run_data_bucket.id

  queue {
    queue_arn = aws_sqs_queue.s3_event_queue.arn

    events = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*",
    ]
  }
}

# Cognito

resource "aws_cognito_user_pool" "user_pool" {
  name = "${local.stack_name_dash}-${terraform.workspace}"

  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = merge(local.default_tags)
}

# Google identity provider
resource "aws_cognito_identity_provider" "identity_provider" {
  user_pool_id  = aws_cognito_user_pool.user_pool.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id                     = data.aws_ssm_parameter.google_oauth_client_id.value
    client_secret                 = data.aws_ssm_parameter.google_oauth_client_secret.value
    authorize_scopes              = "openid profile email"
    attributes_url                = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = true
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    oidc_issuer                   = "https://accounts.google.com"
    token_request_method          = "POST"
    token_url                     = "https://www.googleapis.com/oauth2/v4/token"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

# Identity pool
resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = "Data Portal ${terraform.workspace}"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.user_pool_client.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.user_pool_client_localhost.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }

  tags = merge(local.default_tags)
}

resource "aws_iam_role" "role_authenticated" {
  name = "${local.stack_name_us}_identity_pool_authenticated"
  path = local.iam_role_path

  # IAM role for the identity pool for authenticated identities
  assume_role_policy = templatefile("policies/iam_role_authenticated_assume_role_policy.json", {
    identity_pool_id = aws_cognito_identity_pool.identity_pool.id
  })

  tags = merge(local.default_tags)
}

resource "aws_iam_role_policy" "role_policy_authenticated" {
  name = "${local.stack_name_us}_authenticated_policy"
  role = aws_iam_role.role_authenticated.id

  # IAM role policy for authenticated identities
  # Todo: we should have a explicit reference to our api
  policy = templatefile("policies/iam_role_authenticated_policy.json", {})
}

# Attach the IAM role to the identity pool
resource "aws_cognito_identity_pool_roles_attachment" "identity_pool_role_attach" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id

  roles = {
    "authenticated" = aws_iam_role.role_authenticated.arn
  }
}

# User pool client
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name                         = "${local.stack_name_dash}-app-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = local.callback_urls[terraform.workspace]
  logout_urls   = local.callback_urls[terraform.workspace]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

# User pool client (localhost access)
resource "aws_cognito_user_pool_client" "user_pool_client_localhost" {
  name                         = "${local.stack_name_dash}-app-${terraform.workspace}-localhost"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = [var.localhost_url]
  logout_urls   = [var.localhost_url]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  explicit_auth_flows                  = ["ADMIN_NO_SRP_AUTH"]

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

# Assign an explicit domain
resource "aws_cognito_user_pool_domain" "user_pool_client_domain" {
  domain       = "${local.stack_name_dash}-app-${terraform.workspace}"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

################################################################################
# Deployment pipeline configurations

# Bucket storing codepipeline artifacts (both client and apis)
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = "${local.org_name}-${local.stack_name_dash}-build-${terraform.workspace}"
  acl           = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = merge(local.default_tags)
}

resource "aws_iam_role" "codepipeline_base_role" {
  name = "${local.stack_name_us}_codepipeline_base_role"
  path = local.iam_role_path

  # Base IAM role for codepipeline service
  assume_role_policy = templatefile("policies/codepipeline_base_role_assume_role_policy.json", {})

  tags = merge(local.default_tags)
}

resource "aws_iam_role_policy" "codepipeline_base_role_policy" {
  name   = "${local.stack_name_us}_codepipeline_base_role_policy"
  role   = aws_iam_role.codepipeline_base_role.id

  # Base IAM policy for codepiepline service role
  policy = templatefile("policies/codepipeline_base_role_policy.json", {
    codepipeline_bucket_arn = aws_s3_bucket.codepipeline_bucket.arn
  })
}

# Codepipeline for client
resource "aws_codepipeline" "codepipeline_client" {
  name     = "${local.stack_name_dash}-client-${terraform.workspace}"
  role_arn = aws_iam_role.codepipeline_base_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      output_artifacts = ["SourceArtifact"]
      version          = "1"

      configuration = {
        Owner      = local.org_name
        Repo       = local.github_repo_client
        OAuthToken = data.aws_ssm_parameter.github_pat_oauth_token.value
        Branch     = var.github_branch[terraform.workspace]
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      version         = "1"

      configuration = {
        ProjectName = local.codebuild_project_name_client
      }
    }
  }

  tags = merge(local.default_tags)
}

# Codepipeline for apis
resource "aws_codepipeline" "codepipeline_apis" {
  name     = "${local.stack_name_dash}-apis-${terraform.workspace}"
  role_arn = aws_iam_role.codepipeline_base_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      output_artifacts = ["SourceArtifact"]
      version          = "1"

      configuration = {
        Owner      = local.org_name
        Repo       = local.github_repo_apis
        OAuthToken = data.aws_ssm_parameter.github_pat_oauth_token.value
        Branch     = var.github_branch[terraform.workspace]
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      version         = "1"

      configuration = {
        ProjectName = local.codebuild_project_name_apis
      }
    }
  }

  tags = merge(local.default_tags)
}

resource "aws_iam_role" "codebuild_client_role" {
  name = "${local.stack_name_us}_codebuild_client_service_role"
  path = local.iam_role_path

  # IAM role for code build (client)
  assume_role_policy = templatefile("policies/codebuild_client_role_assume_role_policy.json", {})

  tags = merge(local.default_tags)
}

resource "aws_iam_role" "codebuild_apis_role" {
  name = "${local.stack_name_us}_codebuild_apis_service_role"
  path = local.iam_role_path

  # IAM role for code build (api)
  assume_role_policy = templatefile("policies/codebuild_apis_role_assume_role_policy.json", {})

  tags = merge(local.default_tags)
}

resource "aws_iam_policy" "codebuild_apis_policy" {
  name        = "${local.stack_name_us}_codebuild_apis_service_policy"
  description = "Policy for CodeBuild for backend side of data portal"

  # IAM policy specific for the apis side
  policy = templatefile("policies/codebuild_apis_policy.json", {
    subnet_id0 = sort(data.aws_subnet_ids.private_subnets_ids.ids)[0],
    subnet_id1 = sort(data.aws_subnet_ids.private_subnets_ids.ids)[1],
    subnet_id2 = sort(data.aws_subnet_ids.private_subnets_ids.ids)[2],

    region = data.aws_region.current.name,
    account_id = data.aws_caller_identity.current.account_id
  })
}

# Attach the base policy to the code build role for client
resource "aws_iam_role_policy_attachment" "codebuild_client_role_attach_base_policy" {
  role       = aws_iam_role.codebuild_client_role.name
  policy_arn = aws_iam_policy.codebuild_base_policy.arn
}

# Attach the base policy to the code build role for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_role_attach_base_policy" {
  role       = aws_iam_role.codebuild_apis_role.name
  policy_arn = aws_iam_policy.codebuild_base_policy.arn
}

# Attach specific policies to the code build ro for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_role_attach_specific_policy" {
  role       = aws_iam_role.codebuild_apis_role.name
  policy_arn = aws_iam_policy.codebuild_apis_policy.arn
}

resource "aws_iam_policy" "codebuild_base_policy" {
  name        = "codebuild-${local.stack_name_dash}-base-service-policy"
  description = "Base policy for CodeBuild for data portal site"

  # Base IAM policy for code build
  policy = templatefile("policies/codebuild_base_policy.json", {})
}

# Codebuild project for client
resource "aws_codebuild_project" "codebuild_client" {
  name         = local.codebuild_project_name_client
  service_role = aws_iam_role.codebuild_client_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:4.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "STAGE"
      value = terraform.workspace
    }

    environment_variable {
      name  = "S3"
      value = "s3://${aws_s3_bucket.client_bucket.bucket}"
    }

    environment_variable {
      name  = "API_URL"
      value = local.api_domain
    }

    environment_variable {
      name  = "HTSGET_URL"
      value = data.aws_ssm_parameter.htsget_domain.value
    }

    environment_variable {
      name  = "REGION"
      value = data.aws_region.current.name
    }

    environment_variable {
      name  = "COGNITO_USER_POOL_ID"
      value = aws_cognito_user_pool.user_pool.id
    }

    environment_variable {
      name  = "COGNITO_IDENTITY_POOL_ID"
      value = aws_cognito_identity_pool.identity_pool.id
    }

    environment_variable {
      name  = "COGNITO_APP_CLIENT_ID_STAGE"
      value = aws_cognito_user_pool_client.user_pool_client.id
    }

    environment_variable {
      name  = "OAUTH_DOMAIN"
      value = aws_cognito_user_pool_domain.user_pool_client_domain.domain
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_IN_STAGE"
      value = local.oauth_redirect_url[terraform.workspace]
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_OUT_STAGE"
      value = local.oauth_redirect_url[terraform.workspace]
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${local.org_name}/${local.github_repo_client}.git"
    git_clone_depth = 1
  }

  tags = merge(local.default_tags)
}

# Codebuild project for apis
resource "aws_codebuild_project" "codebuild_apis" {
  name         = local.codebuild_project_name_apis
  service_role = aws_iam_role.codebuild_apis_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:4.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "STAGE"
      value = terraform.workspace
    }

    environment_variable {
      name = "IAP_BASE_URL"      # this is used only within CodeBuild dind scope
      value = "http://localhost"
    }

    environment_variable {
      name = "IAP_AUTH_TOKEN"
      value = "any_value_work"  # this is used only within CodeBuild dind Prism mock stack for build test purpose only
    }
  }

  /* UNCOMMENT TO ADD VPC SUPPORT FOR CODEBUILD
  vpc_config {
    vpc_id = data.aws_vpc.main_vpc.id
    subnets = data.aws_subnet_ids.private_subnets_ids.ids
    security_group_ids = [
      aws_security_group.codebuild_apis_security_group.id,
    ]
  }
  */

  source {
    type            = "GITHUB"
    location        = "https://github.com/${local.org_name}/${local.github_repo_apis}.git"
    git_clone_depth = 1
  }

  tags = merge(local.default_tags)
}

# Codepipeline webhook for client code repository
resource "aws_codepipeline_webhook" "codepipeline_client_webhook" {
  name            = "webhook-github-client"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.codepipeline_client.name

  authentication_configuration {
    secret_token = data.aws_ssm_parameter.github_codepipeline_share_token.value
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }

  tags = merge(local.default_tags)
}

# Codepipeline webhook for apis code repository
resource "aws_codepipeline_webhook" "codepipeline_apis_webhook" {
  name            = "webhook-github-apis"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.codepipeline_apis.name

  authentication_configuration {
    secret_token = data.aws_ssm_parameter.github_codepipeline_share_token.value
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }

  tags = merge(local.default_tags)
}

# Github repository of client
data "github_repository" "client_github_repo" {
  full_name = "${local.org_name}/${local.github_repo_client}"
}

# Github repository of apis
data "github_repository" "apis_github_repo" {
  full_name = "${local.org_name}/${local.github_repo_apis}"
}

# Github repository webhook for client
resource "github_repository_webhook" "client_github_webhook" {
  repository = data.github_repository.client_github_repo.name

  configuration {
    url          = aws_codepipeline_webhook.codepipeline_client_webhook.url
    content_type = "json"
    insecure_ssl = false
    secret       = data.aws_ssm_parameter.github_codepipeline_share_token.value
  }

  events = ["push"]
}

# Github repository webhook for apis
resource "github_repository_webhook" "apis_github_webhook" {
  repository = data.github_repository.apis_github_repo.name

  configuration {
    url          = aws_codepipeline_webhook.codepipeline_apis_webhook.url
    content_type = "json"
    insecure_ssl = false
    secret       = data.aws_ssm_parameter.github_codepipeline_share_token.value
  }

  events = ["push"]
}

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
  subnet_ids = data.aws_subnet_ids.database_subnets_ids.ids
  tags = merge(local.default_tags)
}

resource "aws_rds_cluster" "db" {
  cluster_identifier  = "${local.stack_name_dash}-aurora-cluster"
  engine              = "aurora-mysql"
  engine_mode         = "serverless"
  skip_final_snapshot = true

  database_name   = local.stack_name_us
  master_username = data.aws_ssm_parameter.rds_db_username.value
  master_password = data.aws_ssm_parameter.rds_db_password.value

  vpc_security_group_ids = [aws_security_group.rds_security_group.id]

  # Workaround from https://github.com/terraform-providers/terraform-provider-aws/issues/3060
  db_subnet_group_name = aws_db_subnet_group.rds.name

  enable_http_endpoint = true  # Enable RDS Data API (needed for Query Editor)

  scaling_configuration {
    auto_pause   = var.rds_auto_pause[terraform.workspace]
    min_capacity = var.rds_min_capacity[terraform.workspace]
    max_capacity = var.rds_max_capacity[terraform.workspace]
  }

  backup_retention_period = var.rds_backup_retention_period[terraform.workspace]

  deletion_protection = true

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

# Web Application Firewall for APIs
resource "aws_wafregional_web_acl" "api_web_acl" {
  depends_on = [
    aws_wafregional_sql_injection_match_set.sql_injection_match_set,
    aws_wafregional_rule.api_waf_sql_rule,
  ]

  name        = "dataPortalAPIWebAcl"
  metric_name = "dataPortalAPIWebAcl"

  default_action {
    type = "ALLOW"
  }

  rule {
    action {
      type = "BLOCK"
    }

    priority = 1
    rule_id  = aws_wafregional_rule.api_waf_sql_rule.id
    type     = "REGULAR"
  }

  tags = merge(local.default_tags)
}

# SQL Injection protection
resource "aws_wafregional_rule" "api_waf_sql_rule" {
  depends_on  = [aws_wafregional_sql_injection_match_set.sql_injection_match_set]
  name        = "${local.stack_name_dash}-sql-rule"
  metric_name = "dataPortalSqlRule"

  predicate {
    data_id = aws_wafregional_sql_injection_match_set.sql_injection_match_set.id
    negated = false
    type    = "SqlInjectionMatch"
  }

  tags = merge(local.default_tags)
}

# SQL injection match set
resource "aws_wafregional_sql_injection_match_set" "sql_injection_match_set" {
  name = "${local.stack_name_dash}-api-injection-match-set"

  # Based on the suggestion from 
  # https://d0.awsstatic.com/whitepapers/Security/aws-waf-owasp.pdf
  sql_injection_match_tuple {
    text_transformation = "HTML_ENTITY_DECODE"

    field_to_match {
      type = "QUERY_STRING"
    }
  }

  sql_injection_match_tuple {
    text_transformation = "URL_DECODE"

    field_to_match {
      type = "QUERY_STRING"
    }
  }
}

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

resource "aws_cloudwatch_metric_alarm" "s3_event_sqs_dlq_alarm" {
  alarm_name = "DataPortalS3EventSQSDLQ"
  alarm_description = "Data Portal S3 Events SQS DLQ having > 0 messages"
  alarm_actions = [
    aws_sns_topic.portal_ops_sns_topic.arn
  ]
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 1
  datapoints_to_alarm = 1
  period = 60
  threshold = 0.0
  namespace = "AWS/SQS"
  statistic = "Sum"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions = {
    QueueName = aws_sqs_queue.s3_event_dlq.name
  }
  tags = merge(local.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "ica_ens_event_sqs_dlq_alarm" {
  alarm_name = "DataPortalIAPENSEventSQSDLQ"
  alarm_description = "Data Portal IAP ENS Event SQS DLQ having > 0 messages"
  alarm_actions = [
    aws_sns_topic.portal_ops_sns_topic.arn
  ]
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 1
  datapoints_to_alarm = 1
  period = 60
  threshold = 0.0
  namespace = "AWS/SQS"
  statistic = "Sum"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions = {
    QueueName = aws_sqs_queue.iap_ens_event_dlq.name
  }
  tags = merge(local.default_tags)
}

################################################################################
# Notification: CodeBuild build status send through SNS topic to ChatBot to
# Slack channel #arteria-dev (for DEV account) Or #data-portal (for PROD account)

data "aws_sns_topic" "chatbot_topic" {
  name = "AwsChatBotTopic"
}

locals {
  codebuild_notification_target = {
    prod = aws_sns_topic.portal_ops_sns_topic.arn
    dev  = data.aws_sns_topic.chatbot_topic.arn
  }
}

resource "aws_codestarnotifications_notification_rule" "apis_build_status" {
  name = "${local.stack_name_us}_apis_code_build_status"
  resource = aws_codebuild_project.codebuild_apis.arn
  detail_type = "BASIC"

  target {
    address = local.codebuild_notification_target[terraform.workspace]
  }

  event_type_ids = [
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-succeeded",
  ]

  tags = merge(local.default_tags)
}

resource "aws_codestarnotifications_notification_rule" "client_build_status" {
  name = "${local.stack_name_us}_client_code_build_status"
  resource = aws_codebuild_project.codebuild_client.arn
  detail_type = "BASIC"

  target {
    address = local.codebuild_notification_target[terraform.workspace]
  }

  event_type_ids = [
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-succeeded",
  ]

  tags = merge(local.default_tags)
}

################################################################################
# Save configurations in SSM Parameter Store

# Save these in SSM Parameter Store for frontend client localhost development purpose

resource "aws_ssm_parameter" "cog_user_pool_id" {
  name  = "${local.ssm_param_key_client_prefix}/cog_user_pool_id"
  type  = "String"
  value = aws_cognito_user_pool.user_pool.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "cog_identity_pool_id" {
  name  = "${local.ssm_param_key_client_prefix}/cog_identity_pool_id"
  type  = "String"
  value = aws_cognito_identity_pool.identity_pool.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "cog_app_client_id_local" {
  name  = "${local.ssm_param_key_client_prefix}/cog_app_client_id_local"
  type  = "String"
  value = aws_cognito_user_pool_client.user_pool_client_localhost.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "cog_app_client_id_stage" {
  name  = "${local.ssm_param_key_client_prefix}/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.user_pool_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "oauth_domain" {
  name  = "${local.ssm_param_key_client_prefix}/oauth_domain"
  type  = "String"
  value = aws_cognito_user_pool_domain.user_pool_client_domain.domain
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "oauth_redirect_in_local" {
  name  = "${local.ssm_param_key_client_prefix}/oauth_redirect_in_local"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.user_pool_client_localhost.callback_urls)[0]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "oauth_redirect_out_local" {
  name  = "${local.ssm_param_key_client_prefix}/oauth_redirect_out_local"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.user_pool_client_localhost.logout_urls)[0]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "oauth_redirect_in_stage" {
  name  = "${local.ssm_param_key_client_prefix}/oauth_redirect_in_stage"
  type  = "String"
  value = local.oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "oauth_redirect_out_stage" {
  name  = "${local.ssm_param_key_client_prefix}/oauth_redirect_out_stage"
  type  = "String"
  value = local.oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

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
  value = join(",", data.aws_subnet_ids.private_subnets_ids.ids)
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

resource "aws_ssm_parameter" "s3_event_sqs_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/s3_event_sqs_arn"
  type  = "String"
  value = aws_sqs_queue.s3_event_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "iap_ens_event_sqs_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/iap_ens_event_sqs_arn"
  type  = "String"
  value = aws_sqs_queue.iap_ens_event_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "certificate_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/certificate_arn"
  type  = "String"
  value = aws_acm_certificate.client_cert.arn
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "waf_name" {
  name  = "${local.ssm_param_key_backend_prefix}/waf_name"
  type  = "String"
  value = aws_wafregional_web_acl.api_web_acl.name
  tags  = merge(local.default_tags)
}

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

resource "aws_ssm_parameter" "sqs_notification_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_notification_queue_arn"
  type  = "String"
  value = aws_sqs_queue.notification_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_germline_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_germline_queue_arn"
  type  = "String"
  value = aws_sqs_queue.germline_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_tn_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_tn_queue_arn"
  type  = "String"
  value = aws_sqs_queue.tn_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_report_event_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_report_event_queue_arn"
  type  = "String"
  value = aws_sqs_queue.report_event_queue.arn
  tags  = merge(local.default_tags)
}

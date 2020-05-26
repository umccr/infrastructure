terraform {
  required_version = "~> 0.11.14"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "umccr_data_portal/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

################################################################################
# Generic resources

provider "aws" {
  region = "ap-southeast-2"
}

data "aws_region" "current" {}

# for ACM certificate
provider "aws" {
  region = "us-east-1"
  alias  = "use1"
}

provider "github" {
  # Token to be provided by GITHUB_TOKEN env variable
  # (i.e. export GITHUB_TOKEN=xxx)
  organization = "umccr"
}

locals {
  # Stack name in under socre
  stack_name_us = "data_portal"

  # Stack name in dash
  stack_name_dash = "data-portal"

  client_s3_origin_id           = "clientS3"
  data_portal_domain_prefix     = "data"

  codebuild_project_name_client = "data-portal-client-${terraform.workspace}"
  codebuild_project_name_apis   = "data-portal-apis-${terraform.workspace}"

  api_domain    = "api.${local.app_domain}"
  iam_role_path = "/${local.stack_name_us}/"

  app_domain = "${local.data_portal_domain_prefix}.${var.base_domain[terraform.workspace]}"

  cert_subject_alt_names = {
    prod = ["*.${local.app_domain}", "${var.alias_domain[terraform.workspace]}"]
    dev  = ["*.${local.app_domain}"]
  }

  cloudfront_domain_aliases = {
    prod = ["${local.app_domain}", "${var.alias_domain[terraform.workspace]}"]
    dev  = ["${local.app_domain}"]
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

  LAMBDA_IAM_ROLE_ARN            = "${aws_iam_role.lambda_apis_role.arn}"
  LAMBDA_SUBNET_IDS              = "${join(",", aws_db_subnet_group.rds.subnet_ids)}"
  LAMBDA_SECURITY_GROUP_IDS      = "${aws_security_group.lambda_security_group.id}"
  SSM_KEY_NAME_FULL_DB_URL       = "${aws_ssm_parameter.ssm_full_db_url.name}"
  SSM_KEY_NAME_DJANGO_SECRET_KEY = "${data.aws_ssm_parameter.ssm_django_secret_key.name}"
  SSM_KEY_NAME_LIMS_SPREADSHEET_ID = "${data.aws_ssm_parameter.ssm_lims_spreadsheet_id.name}"
  SSM_KEY_NAME_LIMS_SERVICE_ACCOUNT_JSON = "${data.aws_ssm_parameter.ssm_lims_service_account_json.name}"
  SLACK_CHANNEL = "${var.slack_channel[terraform.workspace]}"
}

################################################################################
# Query for Pre-configured SSM Parameter Store

data "aws_ssm_parameter" "google_oauth_client_id" {
  name  = "/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_id"
}

data "aws_ssm_parameter" "google_oauth_client_secret" {
  name  = "/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_secret"
}

data "aws_ssm_parameter" "ssm_lims_spreadsheet_id" {
  name = "/${local.stack_name_us}/${terraform.workspace}/google/lims_spreadsheet_id"
}

data "aws_ssm_parameter" "ssm_lims_service_account_json" {
  name = "/${local.stack_name_us}/${terraform.workspace}/google/lims_service_account_json"
}

data "aws_ssm_parameter" "ssm_django_secret_key" {
  name = "/${local.stack_name_us}/${terraform.workspace}/django_secret_key"
}

data "aws_ssm_parameter" "rds_db_password" {
  name = "/${local.stack_name_us}/${terraform.workspace}/rds_db_password"
}

data "aws_ssm_parameter" "rds_db_username" {
  name = "/${local.stack_name_us}/${terraform.workspace}/rds_db_username"
}

################################################################################
# Client configurations

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "client_bucket" {
  bucket = "${local.org_name}-${local.stack_name_dash}-client-${terraform.workspace}"
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

# Policy document for the client bucket
data "template_file" "client_bucket_policy" {
  template = "${file("policies/client_bucket_policy.json")}"

  vars {
    client_bucket_arn          = "${aws_s3_bucket.client_bucket.arn}"
    origin_access_identity_arn = "${aws_cloudfront_origin_access_identity.client_origin_access_identity.iam_arn}"
  }
}

# Attach the policy to the client bucket
resource "aws_s3_bucket_policy" "client_bucket_policy" {
  bucket = "${aws_s3_bucket.client_bucket.id}"
  policy = "${data.template_file.client_bucket_policy.rendered}"
}

# Origin access identity for cloudfront to access client s3 bucket
resource "aws_cloudfront_origin_access_identity" "client_origin_access_identity" {
  comment = "Origin access identity for client bucket"
}

# CloudFront layer for client S3 bucket access
resource "aws_cloudfront_distribution" "client_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.client_bucket.bucket_regional_domain_name}"
    origin_id   = "${local.client_s3_origin_id}"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.client_origin_access_identity.cloudfront_access_identity_path}"
    }
  }

  enabled             = true
  aliases             = "${local.cloudfront_domain_aliases[terraform.workspace]}"
  default_root_object = "index.html"

  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate.client_cert.arn}"
    ssl_support_method  = "sni-only"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.client_s3_origin_id}"

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
}

# Hosted zone for organisation domain
data "aws_route53_zone" "org_zone" {
  name = "${var.base_domain[terraform.workspace]}."
}

# Alias the client domain name to CloudFront distribution address
resource "aws_route53_record" "client_alias" {
  zone_id = "${data.aws_route53_zone.org_zone.zone_id}"
  name    = "${local.app_domain}."
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.client_distribution.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.client_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}

# Client certificate validation through a Route53 record
resource "aws_route53_record" "client_cert_validation" {
  zone_id = "${data.aws_route53_zone.org_zone.zone_id}"
  name    = "${aws_acm_certificate.client_cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.client_cert.domain_validation_options.0.resource_record_type}"
  records = ["${aws_acm_certificate.client_cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 300
}

# The certificate for client domain, validating using DNS
resource "aws_acm_certificate" "client_cert" {
  # Certificate needs to be US Virginia region in order to be used by cloudfront distribution
  provider          = "aws.use1"
  domain_name       = "${local.app_domain}"
  validation_method = "DNS"

  subject_alternative_names = "${local.cert_subject_alt_names[terraform.workspace]}"

  lifecycle {
    create_before_destroy = true
  }
}

# Optional automatic certificate validation
# If count = 0, cert will be just created and pending validation
# Visit ACM Console UI and follow up to populate validation records in respective Route53 zones
# See var.certificate_validation note
resource "aws_acm_certificate_validation" "client_cert_dns" {
  count = "${var.certificate_validation[terraform.workspace]}"

  provider                = "aws.use1"
  certificate_arn         = "${aws_acm_certificate.client_cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.client_cert_validation.fqdn}"]

  depends_on = ["aws_route53_record.client_cert_validation"]
}

################################################################################
# Back end configurations

data "template_file" "sqs_iap_ens_event_policy" {
  template = "${file("policies/sqs_iap_ens_event_policy.json")}"

  vars {
    # Use the same name as the one below, if referring there will be cicurlar dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-${terraform.workspace}-iap-ens-event-queue"
  }
}

# SQS Queue for IAP Event Notification Service event delivery
# See https://iap-docs.readme.io/docs/ens_create-an-amazon-sqs-queue
resource "aws_sqs_queue" "iap_ens_event_queue" {
  name   = "${local.stack_name_dash}-${terraform.workspace}-iap-ens-event-queue"
  policy = "${data.template_file.sqs_iap_ens_event_policy.rendered}"
}

data "aws_s3_bucket" "s3_primary_data_bucket" {
  bucket = "${var.s3_primary_data_bucket[terraform.workspace]}"
}

data "aws_s3_bucket" "s3_run_data_bucket" {
  bucket = "${var.s3_run_data_bucket[terraform.workspace]}"
}

data "template_file" "sqs_s3_primary_data_event_policy" {
  template = "${file("policies/sqs_s3_primary_data_event_policy.json")}"

  vars {
    # Use the same name as the one below, if referring there will be
    # cicurlar dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-${terraform.workspace}-s3-event-quque"

    s3_primary_data_bucket_arn = "${data.aws_s3_bucket.s3_primary_data_bucket.arn}"
    s3_run_data_bucket_arn = "${data.aws_s3_bucket.s3_run_data_bucket.arn}"
  }
}

# SQS Queue for S3 event delivery
resource "aws_sqs_queue" "s3_event_queue" {
  name   = "${local.stack_name_dash}-${terraform.workspace}-s3-event-quque"
  policy = "${data.template_file.sqs_s3_primary_data_event_policy.rendered}"
}

# Enable primary data bucket s3 event notification to SQS
resource "aws_s3_bucket_notification" "s3_inventory_notification" {
  bucket = "${data.aws_s3_bucket.s3_primary_data_bucket.id}"

  queue {
    queue_arn = "${aws_sqs_queue.s3_event_queue.arn}"

    events = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*",
    ]
  }
}

# Enable run data bucket s3 event notification to SQS
resource "aws_s3_bucket_notification" "s3_run_data_notification" {
  bucket = "${data.aws_s3_bucket.s3_run_data_bucket.id}"

  queue {
    queue_arn = "${aws_sqs_queue.s3_event_queue.arn}"

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
}

# Google identity provider
resource "aws_cognito_identity_provider" "identity_provider" {
  user_pool_id  = "${aws_cognito_user_pool.user_pool.id}"
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = "${data.aws_ssm_parameter.google_oauth_client_id.value}"
    client_secret    = "${data.aws_ssm_parameter.google_oauth_client_secret.value}"
    authorize_scopes = "openid profile email"
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
    client_id               = "${aws_cognito_user_pool_client.user_pool_client.id}"
    provider_name           = "${aws_cognito_user_pool.user_pool.endpoint}"
    server_side_token_check = false
  }

  cognito_identity_providers {
    client_id               = "${aws_cognito_user_pool_client.user_pool_client_localhost.id}"
    provider_name           = "${aws_cognito_user_pool.user_pool.endpoint}"
    server_side_token_check = false
  }
}

# IAM role for the identity pool for authenticated identities
data "template_file" "iam_role_authenticated_assume_role_policy" {
  template = "${file("policies/iam_role_authenticated_assume_role_policy.json")}"

  vars {
    identity_pool_id = "${aws_cognito_identity_pool.identity_pool.id}"
  }
}

resource "aws_iam_role" "role_authenticated" {
  name = "${local.stack_name_us}_identity_pool_authenticated"
  path = "${local.iam_role_path}"

  assume_role_policy = "${data.template_file.iam_role_authenticated_assume_role_policy.rendered}"
}

# IAM role policy for authenticated identities
data "template_file" "iam_role_authenticated_policy" {
  template = "${file("policies/iam_role_authenticated_policy.json")}"
}

resource "aws_iam_role_policy" "role_policy_authenticated" {
  name = "${local.stack_name_us}_authenticated_policy"
  role = "${aws_iam_role.role_authenticated.id}"

  # Todo: we should have a explicit reference to our api
  policy = "${data.template_file.iam_role_authenticated_policy.rendered}"
}

# Attach the IAM role to the identity pool
resource "aws_cognito_identity_pool_roles_attachment" "identity_pool_role_attach" {
  identity_pool_id = "${aws_cognito_identity_pool.identity_pool.id}"

  roles = {
    "authenticated" = "${aws_iam_role.role_authenticated.arn}"
  }
}

# User pool client
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name                         = "${local.stack_name_dash}-app-${terraform.workspace}"
  user_pool_id                 = "${aws_cognito_user_pool.user_pool.id}"
  supported_identity_providers = ["Google"]

  callback_urls = "${local.callback_urls[terraform.workspace]}"
  logout_urls   = "${local.callback_urls[terraform.workspace]}"

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  # Need to explicitly specify this dependency
  depends_on = ["aws_cognito_identity_provider.identity_provider"]
}

# User pool client (localhost access)
resource "aws_cognito_user_pool_client" "user_pool_client_localhost" {
  name                         = "${local.stack_name_dash}-app-${terraform.workspace}-localhost"
  user_pool_id                 = "${aws_cognito_user_pool.user_pool.id}"
  supported_identity_providers = ["Google"]

  callback_urls = ["${var.localhost_url}"]
  logout_urls   = ["${var.localhost_url}"]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  explicit_auth_flows                  = ["ADMIN_NO_SRP_AUTH"]

  # Need to explicitly specify this dependency
  depends_on = ["aws_cognito_identity_provider.identity_provider"]
}

# Assign an explicit domain
resource "aws_cognito_user_pool_domain" "user_pool_client_domain" {
  domain       = "${local.stack_name_dash}-app-${terraform.workspace}"
  user_pool_id = "${aws_cognito_user_pool.user_pool.id}"
}

################################################################################
# Deployment pipeline configurations

# Bucket storing codepipeline artifacts (both client and apis)
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = "${local.org_name}-${local.stack_name_dash}-build-${terraform.workspace}"
  acl           = "private"
  force_destroy = true
}

# Base IAM role for codepipeline service
data "template_file" "codepipeline_base_role_assume_role_policy" {
  template = "${file("policies/codepipeline_base_role_assume_role_policy.json")}"
}

resource "aws_iam_role" "codepipeline_base_role" {
  name = "${local.stack_name_us}_codepipeline_base_role"
  path = "${local.iam_role_path}"

  assume_role_policy = "${data.template_file.codepipeline_base_role_assume_role_policy.rendered}"
}

# Base IAM policy for codepiepline service role
data "template_file" "codepipeline_base_role_policy" {
  template = "${file("policies/codepipeline_base_role_policy.json")}"

  vars {
    codepipeline_bucket_arn = "${aws_s3_bucket.codepipeline_bucket.arn}"
  }
}

resource "aws_iam_role_policy" "codepipeline_base_role_policy" {
  name   = "${local.stack_name_us}_codepipeline_base_role_policy"
  role   = "${aws_iam_role.codepipeline_base_role.id}"
  policy = "${data.template_file.codepipeline_base_role_policy.rendered}"
}

# Codepipeline for client
resource "aws_codepipeline" "codepipeline_client" {
  name     = "${local.stack_name_dash}-client-${terraform.workspace}"
  role_arn = "${aws_iam_role.codepipeline_base_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline_bucket.bucket}"
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
        Owner = "${local.org_name}"
        Repo  = "${local.github_repo_client}"

        # Use branch for current stage
        Branch = "${var.github_branch[terraform.workspace]}"
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
        ProjectName = "${local.codebuild_project_name_client}"
      }
    }
  }
}

# Codepipeline for apis
resource "aws_codepipeline" "codepipeline_apis" {
  name     = "${local.stack_name_dash}-apis-${terraform.workspace}"
  role_arn = "${aws_iam_role.codepipeline_base_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline_bucket.bucket}"
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
        Owner = "${local.org_name}"
        Repo  = "${local.github_repo_apis}"

        # Use branch for current stage
        Branch = "${var.github_branch[terraform.workspace]}"
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
        ProjectName = "${local.codebuild_project_name_apis}"
      }
    }
  }
}

# IAM role for code build (client)
data "template_file" "codebuild_client_role_assume_role_policy" {
  template = "${file("policies/codebuild_client_role_assume_role_policy.json")}"
}

resource "aws_iam_role" "codebuild_client_role" {
  name = "${local.stack_name_us}_codebuild_client_service_role"
  path = "${local.iam_role_path}"

  assume_role_policy = "${data.template_file.codebuild_client_role_assume_role_policy.rendered}"
}

# IAM role for code build (client)
data "template_file" "codebuild_apis_role_assume_role_policy" {
  template = "${file("policies/codebuild_apis_role_assume_role_policy.json")}"
}

resource "aws_iam_role" "codebuild_apis_role" {
  name = "${local.stack_name_us}_codebuild_apis_service_role"
  path = "${local.iam_role_path}"

  assume_role_policy = "${data.template_file.codebuild_apis_role_assume_role_policy.rendered}"
}

data "aws_caller_identity" "current" {}

# IAM policy specific for the apis side 
data "template_file" "codebuild_apis_policy" {
  template = "${file("policies/codebuild_apis_policy.json")}"

  vars {
    subnet_id = "${aws_subnet.backend_private_1.id}",

    region = "${data.aws_region.current.name}",
    account_id = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_iam_policy" "codebuild_apis_policy" {
  name        = "${local.stack_name_us}_codebuild_apis_service_policy"
  description = "Policy for CodeBuild for backend side of data portal"

  policy = "${data.template_file.codebuild_apis_policy.rendered}"
}

# Attach the base policy to the code build role for client
resource "aws_iam_role_policy_attachment" "codebuild_client_role_attach_base_policy" {
  role       = "${aws_iam_role.codebuild_client_role.name}"
  policy_arn = "${aws_iam_policy.codebuild_base_policy.arn}"
}

# Attach the base policy to the code build role for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_role_attach_base_policy" {
  role       = "${aws_iam_role.codebuild_apis_role.name}"
  policy_arn = "${aws_iam_policy.codebuild_base_policy.arn}"
}

# Attach specific policies to the code build ro for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_role_attach_specific_policy" {
  role       = "${aws_iam_role.codebuild_apis_role.name}"
  policy_arn = "${aws_iam_policy.codebuild_apis_policy.arn}"
}

# Base IAM policy for code build
data "template_file" "codebuild_base_policy" {
  template = "${file("policies/codebuild_base_policy.json")}"
}

resource "aws_iam_policy" "codebuild_base_policy" {
  name        = "codebuild-${local.stack_name_dash}-base-service-policy"
  description = "Base policy for CodeBuild for data portal site"

  policy = "${data.template_file.codebuild_base_policy.rendered}"
}

# Codebuild project for client
resource "aws_codebuild_project" "codebuild_client" {
  name         = "${local.codebuild_project_name_client}"
  service_role = "${aws_iam_role.codebuild_client_role.arn}"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:3.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "STAGE"
      value = "${terraform.workspace}"
    }

    environment_variable {
      name  = "S3"
      value = "s3://${aws_s3_bucket.client_bucket.bucket}"
    }

    environment_variable {
      name  = "API_URL"
      value = "${local.api_domain}"
    }

    environment_variable {
      name  = "REGION"
      value = "${data.aws_region.current.name}"
    }

    environment_variable {
      name  = "COGNITO_USER_POOL_ID"
      value = "${aws_cognito_user_pool.user_pool.id}"
    }

    environment_variable {
      name  = "COGNITO_IDENTITY_POOL_ID"
      value = "${aws_cognito_identity_pool.identity_pool.id}"
    }

    environment_variable {
      name  = "COGNITO_APP_CLIENT_ID_STAGE"
      value = "${aws_cognito_user_pool_client.user_pool_client.id}"
    }

    environment_variable {
      name  = "COGNITO_APP_CLIENT_ID_LOCAL"
      value = "${aws_cognito_user_pool_client.user_pool_client_localhost.id}"
    }

    environment_variable {
      name  = "OAUTH_DOMAIN"
      value = "${aws_cognito_user_pool_domain.user_pool_client_domain.domain}"
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_IN_STAGE"
      value = "${local.oauth_redirect_url[terraform.workspace]}"
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_OUT_STAGE"
      value = "${local.oauth_redirect_url[terraform.workspace]}"
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_IN_LOCAL"
      value = "${aws_cognito_user_pool_client.user_pool_client_localhost.callback_urls[0]}"
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_OUT_LOCAL"
      value = "${aws_cognito_user_pool_client.user_pool_client_localhost.logout_urls[0]}"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${local.org_name}/${local.github_repo_client}.git"
    git_clone_depth = 1
  }
}

# Codebuild project for apis
resource "aws_codebuild_project" "codebuild_apis" {
  name         = "${local.codebuild_project_name_apis}"
  service_role = "${aws_iam_role.codebuild_apis_role.arn}"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:3.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "STAGE"
      value = "${terraform.workspace}"
    }

    environment_variable {
      name  = "API_DOMAIN_NAME"
      value = "${local.api_domain}"
    }

    # Parse the list of security group ids into a single string
    environment_variable {
      name  = "LAMBDA_SECURITY_GROUP_IDS"
      value = "${local.LAMBDA_SECURITY_GROUP_IDS}"
    }

    # Parse the list of subnet ids into a single string
    environment_variable {
      name  = "LAMBDA_SUBNET_IDS"
      value = "${local.LAMBDA_SUBNET_IDS}"
    }

    # ARN of the lambda iam role
    environment_variable {
      name  = "LAMBDA_IAM_ROLE_ARN"
      value = "${local.LAMBDA_IAM_ROLE_ARN}"
    }

    # Name of the SSM KEY for django secret key
    environment_variable {
      name  = "SSM_KEY_NAME_DJANGO_SECRET_KEY"
      value = "${local.SSM_KEY_NAME_DJANGO_SECRET_KEY}"
    }

    # Name of the SSM KEY for database url
    environment_variable {
      name  = "SSM_KEY_NAME_FULL_DB_URL"
      value = "${local.SSM_KEY_NAME_FULL_DB_URL}"
    }

    environment_variable {
      name  = "SSM_KEY_NAME_LIMS_SPREADSHEET_ID"
      value = "${local.SSM_KEY_NAME_LIMS_SPREADSHEET_ID}"
    }

    environment_variable {
      name  = "SSM_KEY_NAME_LIMS_SERVICE_ACCOUNT_JSON"
      value = "${local.SSM_KEY_NAME_LIMS_SERVICE_ACCOUNT_JSON}"
    }

    environment_variable {
      name  = "S3_EVENT_SQS_ARN"
      value = "${aws_sqs_queue.s3_event_queue.arn}"
    }

    environment_variable {
      name  = "IAP_ENS_EVENT_SQS_ARN"
      value = "${aws_sqs_queue.iap_ens_event_queue.arn}"
    }

    environment_variable {
      name  = "CERTIFICATE_ARN"
      value = "${aws_acm_certificate.client_cert.arn}"
    }

    environment_variable {
      name  = "WAF_NAME"
      value = "${aws_wafregional_web_acl.api_web_acl.name}"
    }

    environment_variable {
      name  = "SERVERLESS_DEPLOYMENT_BUCKET"
      value = "${aws_s3_bucket.codepipeline_bucket.bucket}"
    }

    environment_variable {
      name  = "SLACK_CHANNEL"
      value = "${local.SLACK_CHANNEL}"
    }
  }

  # Put it under the lambda VPC allowing for testing
  vpc_config {
    vpc_id = "${aws_vpc.backend_vpc.id}"

    subnets = [
      "${aws_subnet.backend_private_1.id}",
    ]

    security_group_ids = [
      "${aws_security_group.codebuild_apis_security_group.id}",
    ]
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${local.org_name}/${local.github_repo_apis}.git"
    git_clone_depth = 1
  }
}

# Codepipeline webhook for client code repository
resource "aws_codepipeline_webhook" "codepipeline_client_webhook" {
  name            = "webhook-github-client"
  authentication  = "UNAUTHENTICATED"
  target_action   = "Source"
  target_pipeline = "${aws_codepipeline.codepipeline_client.name}"

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}

# Codepipeline webhook for apis code repository
resource "aws_codepipeline_webhook" "codepipeline_apis_webhook" {
  name            = "webhook-github-apis"
  authentication  = "UNAUTHENTICATED"
  target_action   = "Source"
  target_pipeline = "${aws_codepipeline.codepipeline_apis.name}"

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
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
  repository = "${data.github_repository.client_github_repo.name}"

  configuration {
    url          = "${aws_codepipeline_webhook.codepipeline_client_webhook.url}"
    content_type = "json"
    insecure_ssl = false
  }

  events = ["push"]
}

# Github repository webhook for apis
resource "github_repository_webhook" "apis_github_webhook" {
  repository = "${data.github_repository.apis_github_repo.name}"

  configuration {
    url          = "${aws_codepipeline_webhook.codepipeline_apis_webhook.url}"
    content_type = "json"
    insecure_ssl = false
  }

  events = ["push"]
}

# IAM role for lambda functions (to be use by Serverless framework)
data "template_file" "lambda_apis_role_assume_role_policy" {
  template = "${file("policies/lambda_apis_role_assume_role_policy.json")}"
}

resource "aws_iam_role" "lambda_apis_role" {
  name = "${local.stack_name_us}_lambda_apis_role"
  path = "${local.iam_role_path}"

  assume_role_policy = "${data.template_file.lambda_apis_role_assume_role_policy.rendered}"
}

data "template_file" "lambda_apis_policy" {
  template = "${file("policies/lambda_apis_policy.json")}"
}

resource "aws_iam_role_policy" "lambda_apis_role_policy" {
  name = "${local.stack_name_us}_lambda_apis_policy"
  role = "${aws_iam_role.lambda_apis_role.id}"

  policy = "${data.template_file.lambda_apis_policy.rendered}"
}

# Isolated VPC for the backend
resource "aws_vpc" "backend_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# End point for SSM access (from lambda functions)
resource "aws_vpc_endpoint" "ssm_access" {
  vpc_id            = "${aws_vpc.backend_vpc.id}"
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "${aws_security_group.lambda_security_group.id}",
  ]

  subnet_ids = [
    "${aws_subnet.backend_private_2.id}",
    "${aws_subnet.backend_private_3.id}",
  ]

  private_dns_enabled = true
}

# End point for S3 LIMS access (from lambda functions)
resource "aws_vpc_endpoint" "lims_access" {
  vpc_id            = "${aws_vpc.backend_vpc.id}"
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    "${aws_vpc.backend_vpc.default_route_table_id}",
  ]
}

resource "aws_internet_gateway" "backend_gw" {
  vpc_id = "${aws_vpc.backend_vpc.id}"
}

# Elastic IP to be used for the NAT Gateway
resource "aws_eip" "backend_nat_eip" {
  vpc = true
}

# NAT Gateway is required for CodeBuild so it can reach public endpoints
# NAT Gateway sits in the public subnet
resource "aws_nat_gateway" "backend_nat_gw" {
  allocation_id = "${aws_eip.backend_nat_eip.id}"
  subnet_id = "${aws_subnet.backend_public.id}"

  depends_on = ["aws_internet_gateway.backend_gw"]
}

resource "aws_subnet" "backend_public" {
  vpc_id            = "${aws_vpc.backend_vpc.id}"
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-southeast-2a"

  timeouts {
    // https://www.terraform.io/docs/providers/aws/r/subnet.html
    delete = "45m"
  }
}

# Connect public subnet to internet gateway
resource "aws_route_table" "backend_public" {
  vpc_id = "${aws_vpc.backend_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.backend_gw.id}"
  }
}

resource "aws_route_table_association" "backend_public" {
  route_table_id = "${aws_route_table.backend_public.id}"
  subnet_id = "${aws_subnet.backend_public.id}"
}

# Route table for private subnets
resource "aws_route_table" "backend_private" {
  vpc_id = "${aws_vpc.backend_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.backend_nat_gw.id}"
  }
}

resource "aws_subnet" "backend_private_1" {
  vpc_id            = "${aws_vpc.backend_vpc.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"

  timeouts {
    // https://www.terraform.io/docs/providers/aws/r/subnet.html
    delete = "45m"
  }
}

resource "aws_route_table_association" "backend_private_1" {
  route_table_id = "${aws_route_table.backend_private.id}"
  subnet_id = "${aws_subnet.backend_private_1.id}"
}

resource "aws_subnet" "backend_private_2" {
  vpc_id            = "${aws_vpc.backend_vpc.id}"
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-2b"

  timeouts {
    // https://www.terraform.io/docs/providers/aws/r/subnet.html
    delete = "45m"
  }
}

resource "aws_route_table_association" "backend_private_2" {
  route_table_id = "${aws_route_table.backend_private.id}"
  subnet_id = "${aws_subnet.backend_private_2.id}"
}

resource "aws_subnet" "backend_private_3" {
  vpc_id            = "${aws_vpc.backend_vpc.id}"
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-2c"

  timeouts {
    // https://www.terraform.io/docs/providers/aws/r/subnet.html
    delete = "45m"
  }
}

resource "aws_route_table_association" "backend_private_3" {
  route_table_id = "${aws_route_table.backend_private.id}"
  subnet_id = "${aws_subnet.backend_private_3.id}"
}


# Security group for lambda functions
resource "aws_security_group" "lambda_security_group" {
  vpc_id      = "${aws_vpc.backend_vpc.id}"
  name        = "${local.stack_name_us}_lambda"
  description = "Security group for lambda functions"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Use a seperate security group for CodeBuild for apis
resource "aws_security_group" "codebuild_apis_security_group" {
  vpc_id      = "${aws_vpc.backend_vpc.id}"
  name        = "${local.stack_name_us}_codebuild_apis"
  description = "Security group for codebuild for backend (apis)"

  # No ingress traffic allowed to your builds
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for RDS
resource "aws_security_group" "rds_security_group" {
  vpc_id      = "${aws_vpc.backend_vpc.id}"
  name        = "${local.stack_name_us}_rds"
  description = "Allow inbound traffic for RDS MySQL"

  # Allow access from lambda functions and codebuild for apis
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"

    # Allowing both lambda functions and codebuild (intergation tests) to access RDS
    security_groups = [
      "${aws_security_group.lambda_security_group.id}",
      "${aws_security_group.codebuild_apis_security_group.id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS DB
resource "aws_db_subnet_group" "rds" {
  name = "${local.stack_name_us}_db_subnet_group"

  subnet_ids = [
    "${aws_subnet.backend_private_2.id}",
    "${aws_subnet.backend_private_3.id}",
  ]
}

resource "aws_rds_cluster" "db" {
  cluster_identifier  = "${local.stack_name_dash}-aurora-cluster"
  engine              = "aurora"                                  # (for MySQL 5.6-compatible Aurora)
  engine_mode         = "serverless"
  skip_final_snapshot = true

  database_name   = "${local.stack_name_us}"
  master_username = "${data.aws_ssm_parameter.rds_db_username.value}"
  master_password = "${data.aws_ssm_parameter.rds_db_password.value}"

  vpc_security_group_ids = ["${aws_security_group.rds_security_group.id}"]

  # Workfround from https://github.com/terraform-providers/terraform-provider-aws/issues/3060
  db_subnet_group_name = "${aws_db_subnet_group.rds.name}"

  scaling_configuration {
    auto_pause   = "${var.rds_auto_pause[terraform.workspace]}"
    min_capacity = "${var.rds_min_capacity[terraform.workspace]}"
    max_capacity = "${var.rds_max_capacity[terraform.workspace]}"
  }
}

# Composed database url for backend to use
resource "aws_ssm_parameter" "ssm_full_db_url" {
  name        = "/${local.stack_name_us}/${terraform.workspace}/full_db_url"
  type        = "SecureString"
  description = "Database url used by the Django app"
  value       = "mysql://${data.aws_ssm_parameter.rds_db_username.value}:${data.aws_ssm_parameter.rds_db_password.value}@${aws_rds_cluster.db.endpoint}:${aws_rds_cluster.db.port}/${aws_rds_cluster.db.database_name}"
}

################################################################################
# Security configurations

# Web Application Firewall for APIs
resource "aws_wafregional_web_acl" "api_web_acl" {
  depends_on = [
    "aws_wafregional_sql_injection_match_set.sql_injection_match_set",
    "aws_wafregional_rule.api_waf_sql_rule",
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
    rule_id  = "${aws_wafregional_rule.api_waf_sql_rule.id}"
    type     = "REGULAR"
  }
}

# SQL Injection protection
resource "aws_wafregional_rule" "api_waf_sql_rule" {
  depends_on  = ["aws_wafregional_sql_injection_match_set.sql_injection_match_set"]
  name        = "${local.stack_name_dash}-sql-rule"
  metric_name = "dataPortalSqlRule"

  predicate {
    data_id = "${aws_wafregional_sql_injection_match_set.sql_injection_match_set.id}"
    negated = false
    type    = "SqlInjectionMatch"
  }
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

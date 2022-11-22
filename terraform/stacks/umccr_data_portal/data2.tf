################################################################################
# data2 Client configurations
#
# FIXME: Data Portal App Client for data2
#  currently using `portal.umccr.org` `portal.prod.umccr.org`
#  This is meant to be thrown away at some point around Q2 '23.
#  Only targeted for PROD.
#  See also `app_data_portal_data2.tf` from `cognito_aai` stack
#  https://umccr.slack.com/archives/CP356DDCH/p1666922554239469?thread_ts=1666786848.939379&cid=CP356DDCH
#

locals {
  create_data2 = {
    prod = 1
    dev  = 0
    stg  = 0
  }

  data2                     = "data2"
  data2_client_s3_origin_id = "data2clientS3"

  data2_cert_subject_alt_names = {
    prod = sort(["*.${local.app_domain2}", var.alias_domain2[terraform.workspace]])
    dev  = sort(["*.${local.app_domain2}"])
    stg  = sort(["*.${local.app_domain2}"])
  }

  data2_cloudfront_domain_aliases = {
    prod = [local.app_domain2, var.alias_domain2[terraform.workspace]]
    dev  = [local.app_domain2]
    stg  = [local.app_domain2]
  }

  data2_param_prefix = "/data_portal/client/data2"

  data2_codebuild_project_name = "${local.stack_name_dash}-${local.data2}-${terraform.workspace}"
}

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "data2_client" {
  count  = local.create_data2[terraform.workspace]
  bucket = "${local.org_name}-${local.stack_name_dash}-client-${local.data2}"
  tags   = merge(local.default_tags)
}

resource "aws_s3_bucket_acl" "data2_client" {
  count  = local.create_data2[terraform.workspace]
  bucket = aws_s3_bucket.data2_client[0].id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data2_client" {
  count  = local.create_data2[terraform.workspace]
  bucket = aws_s3_bucket.data2_client[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_website_configuration" "data2_client" {
  count  = local.create_data2[terraform.workspace]
  bucket = aws_s3_bucket.data2_client[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Attach the policy to the client bucket
resource "aws_s3_bucket_policy" "data2_client_bucket_policy" {
  count  = local.create_data2[terraform.workspace]
  bucket = aws_s3_bucket.data2_client[0].id

  # Policy document for the client bucket
  policy = templatefile("policies/client_bucket_policy.json", {
    client_bucket_arn          = aws_s3_bucket.data2_client[0].arn
    origin_access_identity_arn = aws_cloudfront_origin_access_identity.data2_client_origin_access_identity[0].iam_arn
  })
}

# Origin access identity for cloudfront to access client s3 bucket
resource "aws_cloudfront_origin_access_identity" "data2_client_origin_access_identity" {
  count   = local.create_data2[terraform.workspace]
  comment = "Origin access identity for data2 client bucket"
}

# CloudFront layer for client S3 bucket access
resource "aws_cloudfront_distribution" "data2_client_distribution" {
  count = local.create_data2[terraform.workspace]

  origin {
    domain_name = aws_s3_bucket.data2_client[0].bucket_regional_domain_name
    origin_id   = local.data2_client_s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.data2_client_origin_access_identity[0].cloudfront_access_identity_path
    }
  }

  enabled             = true
  aliases             = local.data2_cloudfront_domain_aliases[terraform.workspace]
  default_root_object = "index.html"

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.data2_client_cert[0].arn
    ssl_support_method  = "sni-only"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.data2_client_s3_origin_id

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

# Alias the client domain name to CloudFront distribution address
resource "aws_route53_record" "data2_client_alias" {
  count   = local.create_data2[terraform.workspace]
  zone_id = data.aws_route53_zone.org_zone.zone_id
  name    = "${local.app_domain2}."
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.data2_client_distribution[0].domain_name
    zone_id                = aws_cloudfront_distribution.data2_client_distribution[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# The certificate for client domain, validating using DNS
resource "aws_acm_certificate" "data2_client_cert" {
  count = local.create_data2[terraform.workspace]

  # Certificate needs to be US Virginia region in order to be used by cloudfront distribution
  provider    = aws.use1
  domain_name = local.app_domain2

  # FIXME: Visit ACM Console UI and follow up to populate validation records in respective Route53 zones
  #  See var.certificate_validation note
  validation_method = "DNS"

  subject_alternative_names = local.data2_cert_subject_alt_names[terraform.workspace]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags)
}


################################################################################
# Deployment pipeline configurations

# Codepipeline for data2 client
resource "aws_codepipeline" "codepipeline_data2" {
  count    = local.create_data2[terraform.workspace]
  name     = "${local.stack_name_dash}-${local.data2}-${terraform.workspace}"
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
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      output_artifacts = ["SourceArtifact"]
      version          = "1"

      configuration = {
        ConnectionArn    = data.aws_ssm_parameter.codestar_github_arn.value
        FullRepositoryId = "${local.org_name}/${local.github_repo_client}"
        BranchName       = "main"  # NOTE: this is intended
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
        ProjectName = local.data2_codebuild_project_name
      }
    }
  }

  tags = merge(local.default_tags)
}

data "aws_ssm_parameter" "data2_cog_app_client_id_stage" {
  count = local.create_data2[terraform.workspace]
  name  = "${local.data2_param_prefix}/cog_app_client_id_stage"
}

data "aws_ssm_parameter" "data2_oauth_redirect_in_stage" {
  count = local.create_data2[terraform.workspace]
  name  = "${local.data2_param_prefix}/oauth_redirect_in_stage"
}

data "aws_ssm_parameter" "data2_oauth_redirect_out_stage" {
  count = local.create_data2[terraform.workspace]
  name  = "${local.data2_param_prefix}/oauth_redirect_out_stage"
}

# Codebuild project for client
resource "aws_codebuild_project" "codebuild_data2" {
  count        = local.create_data2[terraform.workspace]
  name         = local.data2_codebuild_project_name
  service_role = aws_iam_role.codebuild_client_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "STAGE"
      value = terraform.workspace
    }

    environment_variable {
      name  = "S3"
      value = "s3://${aws_s3_bucket.data2_client[0].bucket}"  # NOTE: pointing to data2 bucket
    }

    environment_variable {
      name  = "API_URL"
      # FIXME: https://github.com/umccr/infrastructure/issues/272
      # value = local.api_domain
      value = local.api_domain2
    }

    environment_variable {
      name  = "HTSGET_URL"
      value = data.aws_ssm_parameter.htsget_domain.value
    }

    environment_variable {
      name  = "GPL_SUBMIT_JOB"
      value = data.aws_ssm_parameter.gpl_submit_job.value
    }

    environment_variable {
      name  = "GPL_SUBMIT_JOB_MANUAL"
      value = data.aws_ssm_parameter.gpl_submit_job_manual.value
    }

    #    environment_variable {
    #      name  = "GPL_CREATE_LINX_PLOT"
    #      value = data.aws_ssm_parameter.gpl_create_linx_plot.value
    #    }

    environment_variable {
      name  = "REGION"
      value = data.aws_region.current.name
    }

    environment_variable {
      name  = "COGNITO_USER_POOL_ID"
      value = data.aws_ssm_parameter.cog_user_pool_id.value
    }

    environment_variable {
      name  = "COGNITO_IDENTITY_POOL_ID"
      value = data.aws_ssm_parameter.cog_identity_pool_id.value
    }

    environment_variable {
      name  = "COGNITO_APP_CLIENT_ID_STAGE"
      value = data.aws_ssm_parameter.data2_cog_app_client_id_stage[0].value
    }

    environment_variable {
      name  = "OAUTH_DOMAIN"
      value = data.aws_ssm_parameter.oauth_domain.value
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_IN_STAGE"
      value = data.aws_ssm_parameter.data2_oauth_redirect_in_stage[0].value
    }

    environment_variable {
      name  = "OAUTH_REDIRECT_OUT_STAGE"
      value = data.aws_ssm_parameter.data2_oauth_redirect_out_stage[0].value
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${local.org_name}/${local.github_repo_client}.git"
    git_clone_depth = 1
  }

  tags = merge(local.default_tags)
}

resource "aws_codestarnotifications_notification_rule" "data2_build_status" {
  count       = local.create_data2[terraform.workspace]
  name        = "${local.stack_name_us}_${local.data2}_code_build_status"
  resource    = aws_codebuild_project.codebuild_data2[0].arn
  detail_type = "BASIC"

  target {
    address = local.notification_sns_topic_arn[terraform.workspace]
  }

  event_type_ids = [
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-succeeded",
  ]

  tags = merge(local.default_tags)
}

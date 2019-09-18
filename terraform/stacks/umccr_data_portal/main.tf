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

# Secrets manager
data "aws_secretsmanager_secret_version" "secrets" {
  secret_id = "data_portal"
}

# Secret helper for retrieving value from map (as we dont have jsondecode in v11)
data "external" "secrets_helper" {
  program = ["echo", "${data.aws_secretsmanager_secret_version.secrets.secret_string}"]
}

locals {
    # Stack name in under socre
    stack_name_us       = "data_portal"
    # Stack name in dash
    stack_name_dash     = "data-portal"

    client_s3_origin_id = "clientS3"
    data_portal_domain_prefix = "data-portal"
    google_app_secret = "${data.external.secrets_helper.result["google_app_secret"]}"
    codebuild_project_name_client = "data-portal-client-${terraform.workspace}"
    codebuild_project_name_apis = "data-portal-apis-${terraform.workspace}"

    api_domain = "api.${aws_acm_certificate.client_cert.domain_name}"
    iam_role_path = "/${local.stack_name_us}/"

    site_domain = "${local.data_portal_domain_prefix}.${var.org_domain[terraform.workspace]}"

    org_name = "umccr"

    github_repo_client = "data-portal-client"
    github_repo_apis   = "data-portal-apis"

    rds_db_password = "${data.aws_ssm_parameter.rds_db_password.value}"

    LAMBDA_IAM_ROLE_ARN = "${aws_iam_role.lambda_apis_role.arn}"
    LAMBDA_SUBNET_IDS = "${join(",", data.aws_subnet_ids.default.ids)}"
    LAMBDA_SECURITY_GROUP_IDS = "${data.aws_security_group.default.id}"
    SSM_KEY_NAME_FULL_DB_URL = "${aws_ssm_parameter.ssm_full_db_url.name}"
    SSM_KEY_NAME_DJANGO_SECRET_KEY =  "${data.aws_ssm_parameter.ssm_django_secret_key.name}"
} 

################################################################################
# Client configurations

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "client_bucket" {
    bucket  = "${local.org_name}-${local.stack_name_dash}-client-${terraform.workspace}"
    acl     = "private"

    website {
        index_document = "index.html"
        error_document = "index.html"
    }
}

# Policy document for the client bucket
data "template_file" "client_bucket_policy" {
    template = "${file("policies/client_bucket_policy.json")}"
    vars {
        client_bucket_arn   = "${aws_s3_bucket.client_bucket.arn}"
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

    enabled                 = true
    aliases                 = ["${local.site_domain}"]
    default_root_object     = "index.html"
    viewer_certificate {
        acm_certificate_arn = "${aws_acm_certificate_validation.client_cert_dns.certificate_arn}"
        ssl_support_method  = "sni-only"
    }

    default_cache_behavior {
        allowed_methods         = ["GET", "HEAD"]
        cached_methods          = ["GET", "HEAD"]
        target_origin_id        = "${local.client_s3_origin_id}"
        
        forwarded_values {
            query_string = false

            cookies {
                forward = "none"
            }    
        }

        viewer_protocol_policy  = "redirect-to-https"
        min_ttl                 = 0
        default_ttl             = 0
        max_ttl                 = 0
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    # Route handling for SPA
    custom_error_response {
        error_caching_min_ttl   = 0
        error_code              = 404
        response_code           = 200
        response_page_path      = "/index.html"
    }
}

# Hosted zone for organisation domain
data "aws_route53_zone" "org_zone" {
    name = "${var.org_domain[terraform.workspace]}."
}

# Alias the client domain name to CloudFront distribution address
resource "aws_route53_record" "client_alias" {
    zone_id = "${data.aws_route53_zone.org_zone.zone_id}"
    name = "${local.data_portal_domain_prefix}.${data.aws_route53_zone.org_zone.name}"
    type = "A"
    alias {
        name                    = "${aws_cloudfront_distribution.client_distribution.domain_name}"
        zone_id                 = "${aws_cloudfront_distribution.client_distribution.hosted_zone_id}"
        evaluate_target_health  = false
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
    provider            = "aws.use1"
    domain_name         = "${local.site_domain}"
    validation_method   = "DNS"

    lifecycle {
        create_before_destroy = true
    }
}

# Certificate validation for client domain
resource "aws_acm_certificate_validation" "client_cert_dns" {
    provider                = "aws.use1"
    certificate_arn         = "${aws_acm_certificate.client_cert.arn}"
    validation_record_fqdns = ["${aws_route53_record.client_cert_validation.fqdn}"]
}

################################################################################
# Back end configurations
# The certificate for client domain, validating using DNS

# ACM certificate for subdomain, supporting for custom API
resource "aws_acm_certificate" "subdomain_cert" {
    # Certificate needs to be US Virginia region in order to be used by cloudfront distribution
    provider            = "aws.use1"
    domain_name         = "*.${local.site_domain}"
    validation_method   = "DNS"

    lifecycle {
        create_before_destroy = true
    }

    # Wait for our main certificate to be ready as it has the same validation CNAME
    depends_on          = ["aws_acm_certificate_validation.client_cert_dns"]
}

resource "aws_acm_certificate_validation" "subdomain_cert_validation" {
    provider                = "aws.use1"
    certificate_arn         = "${aws_acm_certificate.subdomain_cert.arn}"
    # We can use the same one as client cert as this domain is a sub domain
    validation_record_fqdns = ["${aws_route53_record.client_cert_validation.fqdn}"]
}

# Custom domain is to be created by Serverless Domain Manager
# resource "aws_api_gateway_domain_name" "api_domain" {
#     certificate_arn = "${aws_acm_certificate_validation.client_cert_dns.certificate_arn}"
#     domain_name     = "api.${aws_acm_certificate.client_cert.domain_name}"
# }

# resource "aws_route53_record" "api_domain_route53_record" {
#   name    = "${aws_api_gateway_domain_name.api_domain.domain_name}"
#   type    = "A"
#   zone_id = "${data.aws_route53_zone.org_zone.zone_id}"

#   alias {
#     evaluate_target_health = true
#     name                   = "${aws_api_gateway_domain_name.api_domain.cloudfront_domain_name}"
#     zone_id                = "${aws_api_gateway_domain_name.api_domain.cloudfront_zone_id}"
#   }
# }

data "aws_s3_bucket" "s3_primary_data_bucket" {
    bucket = "${var.s3_primary_data_bucket[terraform.workspace]}"
}

resource "aws_s3_bucket" "s3_inventory_bucket" {
    bucket = "${local.stack_name_dash}-inventory"
}

resource "aws_s3_bucket_inventory" "name" {
    bucket = "${data.aws_s3_bucket.s3_primary_data_bucket}"
    name = "{local.stack_name_dash}-inventory"

    included_object_versions = "current"
    
    schedule {
        frequency = "Daily"
    }

    destination {
        bucket {
            bucket_arn = "${aws_s3_bucket.s3_inventory_bucket.arn}"
            format = "CSV"
        }
    }
}


data "aws_s3_bucket" "lims_bucket" {
    bucket = "${var.lims_bucket[terraform.workspace]}"
}

data "template_file" "sqs_s3_inventory_event_policy" {
    template = "${file("policies/sqs_s3_inventory_event_policy.json")}"

    vars {        
        # Use the same name as the one below, if referring there will be
        # cicurlar dependency
        sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-${terraform.workspace}-s3-event-quque"
        s3_inventory_bucket_arn = "${data.aws_s3_bucket.s3_inventory_bucket.arn}"
    }
}

# SQS Queue for S3 event delivery
resource "aws_sqs_queue" "s3_event_queue" {
    name = "${local.stack_name_dash}-${terraform.workspace}-s3-event-quque"
    policy = "${data.template_file.sqs_s3_inventory_event_policy.rendered}"
}

# Enable s3 event notification for the invevntory bucket --> SQS
resource "aws_s3_bucket_notification" "s3_inventory_notification" {
    bucket = "${data.aws_s3_bucket.s3_inventory_bucket.id}"

    queue {
        queue_arn = "${aws_sqs_queue.s3_event_queue.arn}"
        events = [
            "s3:ObjectCreated:*", 
            "s3:ObjectRemoved:*"
        ]
    }
}

# Cognito
resource "aws_cognito_user_pool" "user_pool" {
    name = "${local.stack_name_dash}-${terraform.workspace}"
}

# Google identity provider
resource "aws_cognito_identity_provider" "identity_provider" {
    user_pool_id    = "${aws_cognito_user_pool.user_pool.id}"
    provider_name   = "Google"
    provider_type   = "Google"

    provider_details = {
        authorize_scopes    = "profile email openid"
        client_id           = "${var.google_app_id[terraform.workspace]}"
        client_secret       = "${local.google_app_secret}"
    }

    attribute_mapping = {
        email       = "email"
        username    = "sub"
    }
}

# Identity pool
resource "aws_cognito_identity_pool" "identity_pool" {
    identity_pool_name                  = "Data Portal ${terraform.workspace}"
    allow_unauthenticated_identities    = false

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
    name                                    = "${local.stack_name_dash}-app-${terraform.workspace}"
    user_pool_id                            = "${aws_cognito_user_pool.user_pool.id}"
    supported_identity_providers            = ["Google"]

    callback_urls                           = ["https://${local.site_domain}"]
    logout_urls                             = ["https://${local.site_domain}"]

    generate_secret                         = false

    allowed_oauth_flows                     = ["code"]
    allowed_oauth_flows_user_pool_client    = true
    allowed_oauth_scopes                    = ["email", "openid",  "aws.cognito.signin.user.admin", "profile"]

    # Need to explicitly specify this dependency
    depends_on                              = ["aws_cognito_identity_provider.identity_provider"]
}

# User pool client (localhost access)
resource "aws_cognito_user_pool_client" "user_pool_client_localhost" {
    name                                    = "${local.stack_name_dash}-app-${terraform.workspace}-localhost"
    user_pool_id                            = "${aws_cognito_user_pool.user_pool.id}"
    supported_identity_providers            = ["Google"]

    callback_urls                           = ["${var.localhost_url}"]
    logout_urls                             = ["${var.localhost_url}"]

    generate_secret                         = false

    allowed_oauth_flows                     = ["code"]
    allowed_oauth_flows_user_pool_client    = true
    allowed_oauth_scopes                    = ["email", "openid", "aws.cognito.signin.user.admin", "profile"]
    explicit_auth_flows                     = ["ADMIN_NO_SRP_AUTH"]

    # Need to explicitly specify this dependency
    depends_on                              = ["aws_cognito_identity_provider.identity_provider"]
}

# Assign an explicit domain
resource "aws_cognito_user_pool_domain" "user_pool_client_domain" {
    domain          = "${local.stack_name_dash}-app-${terraform.workspace}"
    user_pool_id    = "${aws_cognito_user_pool.user_pool.id}"
}

################################################################################
# Deployment pipeline configurations

# Bucket storing codepipeline artifacts (both client and apis)
resource "aws_s3_bucket" "codepipeline_bucket" {
    bucket  = "${local.org_name}-${local.stack_name_dash}-codepipeline-artifacts-${terraform.workspace}"
    acl     = "private"
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
    name = "${local.stack_name_us}_codepipeline_base_role_policy"
    role = "${aws_iam_role.codepipeline_base_role.id}"
    policy = "${data.template_file.codepipeline_base_role_policy.rendered}"
}

# Codepipeline for client
resource "aws_codepipeline" "codepipeline_client" {
    name        = "${local.stack_name_dash}-client-${terraform.workspace}"
    role_arn    = "${aws_iam_role.codepipeline_base_role.arn}"

    artifact_store {
        location    = "${aws_s3_bucket.codepipeline_bucket.bucket}"
        type        = "S3"
    }

    stage {
        name = "Source"

        action {
            name                = "Source"
            category            = "Source"
            owner               = "ThirdParty"
            provider            = "GitHub"
            output_artifacts    = ["SourceArtifact"]
            version             = "1"
            
            configuration = {
                Owner   = "${local.org_name}"
                Repo    = "${local.github_repo_client}"
                # Use branch for current stage
                Branch  = "${var.github_branch[terraform.workspace]}"
            }
        }
    }

    stage {
        name = "Build"

        action {
            name                = "Build"
            category            = "Build"
            owner               = "AWS"
            provider            = "CodeBuild"
            input_artifacts     = ["SourceArtifact"]
            version             = "1"

            configuration = {
                ProjectName     = "${local.codebuild_project_name_client}"
            }
        }
    }
}

# Codepipeline for apis
resource "aws_codepipeline" "codepipeline_apis" {
    name        = "${local.stack_name_dash}-apis-${terraform.workspace}"
    role_arn    = "${aws_iam_role.codepipeline_base_role.arn}"

    artifact_store {
        location    = "${aws_s3_bucket.codepipeline_bucket.bucket}"
        type        = "S3"
    }

    stage {
        name = "Source"

        action {
            name                = "Source"
            category            = "Source"
            owner               = "ThirdParty"
            provider            = "GitHub"
            output_artifacts    = ["SourceArtifact"]
            version             = "1"
            
            configuration = {
                Owner   = "${local.org_name}"
                Repo    = "${local.github_repo_apis}"
                # Use branch for current stage
                Branch  = "${var.github_branch[terraform.workspace]}"
            }
        }
    }

    stage {
        name = "Build"

        action {
            name                = "Build"
            category            = "Build"
            owner               = "AWS"
            provider            = "CodeBuild"
            input_artifacts     = ["SourceArtifact"]
            version             = "1"

            configuration = {
                ProjectName     = "${local.codebuild_project_name_apis}"
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

# IAM policy specific for the apis side 
data "template_file" "codebuild_apis_policy" {
    template = "${file("policies/codebuild_apis_policy.json")}"
}
resource "aws_iam_policy" "codebuild_apis_policy" {
    name = "${local.stack_name_us}_codebuild_apis_service_policy"
    description = "Policy for CodeBuild for backend side of data portal"

    policy = "${data.template_file.codebuild_apis_policy.rendered}"
}

# Attach the base policy to the code build role for client
resource "aws_iam_role_policy_attachment" "codebuild_client_role_attach_base_policy" {
    role        = "${aws_iam_role.codebuild_client_role.name}"
    policy_arn  = "${aws_iam_policy.codebuild_base_policy.arn}"
}

# Attach the base policy to the code build role for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_role_attach_base_policy" {
    role        = "${aws_iam_role.codebuild_apis_role.name}"
    policy_arn  = "${aws_iam_policy.codebuild_base_policy.arn}"
}

# Attach specific policies to the code build ro for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_role_attach_specific_policy" {
    role        = "${aws_iam_role.codebuild_apis_role.name}"
    policy_arn  = "${aws_iam_policy.codebuild_apis_policy.arn}"
}


# Base IAM policy for code build
data "template_file" "codebuild_base_policy" {
    template = "${file("policies/codebuild_base_policy.json")}"
}

resource "aws_iam_policy" "codebuild_base_policy" {
    name = "codebuild-${local.stack_name_dash}-base-service-policy"
    description = "Base policy for CodeBuild for data portal site"

    policy = "${data.template_file.codebuild_base_policy.rendered}"
}

# Codebuild project for client
resource "aws_codebuild_project" "codebuild_client" {
    name = "${local.codebuild_project_name_client}"
    service_role = "${aws_iam_role.codebuild_client_role.arn}"

    artifacts {
        type = "NO_ARTIFACTS"
    }

    environment {
        compute_type            = "BUILD_GENERAL1_SMALL"
        image                   = "aws/codebuild/standard:2.0"
        type                    = "LINUX_CONTAINER"
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
            value = "${aws_cognito_user_pool_client.user_pool_client.callback_urls[0]}"
        }

        environment_variable {
            name  = "OAUTH_REDIRECT_OUT_STAGE"
            value = "${aws_cognito_user_pool_client.user_pool_client.logout_urls[0]}"
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
        type = "GITHUB"
        location = "https://github.com/${local.org_name}/${local.github_repo_client}.git"
        git_clone_depth = 1
    }
}

# Codebuild project for apis
resource "aws_codebuild_project" "codebuild_apis" {
    name = "${local.codebuild_project_name_apis}"
    service_role = "${aws_iam_role.codebuild_apis_role.arn}"

    artifacts {
        type = "NO_ARTIFACTS"
    }

    environment {
        compute_type            = "BUILD_GENERAL1_SMALL"
        image                   = "aws/codebuild/standard:2.0"
        type                    = "LINUX_CONTAINER"
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
            name = "LAMBDA_SECURITY_GROUP_IDS"
            value = "${local.LAMBDA_SECURITY_GROUP_IDS}"
        }

        # Parse the list of subnet ids into a single string
        environment_variable {
            name = "LAMBDA_SUBNET_IDS"
            value = "${local.LAMBDA_SUBNET_IDS}"
        }

        # ARN of the lambda iam role
        environment_variable {
            name = "LAMBDA_IAM_ROLE_ARN"
            value = "${local.LAMBDA_IAM_ROLE_ARN}"
        }

        # Name of the SSM KEY for django secret key
        environment_variable {
            name = "SSM_KEY_NAME_DJANGO_SECRET_KEY"
            value = "${local.SSM_KEY_NAME_DJANGO_SECRET_KEY}"
        }

        # Name of the SSM KEY for database url
        environment_variable {
            name = "SSM_KEY_NAME_FULL_DB_URL"
            value = "${local.SSM_KEY_NAME_FULL_DB_URL}"
        }

        environment_variable {
            name = "LIMS_BUCKET_NAME"
            value = "${data.aws_s3_bucket.lims_bucket.bucket}"
        }

        environment_variable {
            name = "LIMS_CSV_OBJECT_KEY"
            value = "${var.lims_csv_file_key}"
        }

        environment_variable {
            name = "S3_EVENT_SQS_ARN"
            value = "${aws_sqs_queue.s3_event_queue.arn}"
        }
    }

    source {
        type = "GITHUB"
        location = "https://github.com/${local.org_name}/${local.github_repo_apis}.git"
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
        json_path       = "$.ref"
        match_equals    = "refs/heads/{Branch}"
    }
}

# Codepipeline webhook for apis code repository
resource "aws_codepipeline_webhook" "codepipeline_apis_webhook" {
    name            = "webhook-github-apis"
    authentication  = "UNAUTHENTICATED"
    target_action   = "Source"
    target_pipeline = "${aws_codepipeline.codepipeline_apis.name}"

    filter {
        json_path       = "$.ref"
        match_equals    = "refs/heads/{Branch}"
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
    repository  = "${data.github_repository.client_github_repo.name}"

    configuration {
        url             = "${aws_codepipeline_webhook.codepipeline_client_webhook.url}"
        content_type    = "json"
        insecure_ssl    = false
    }

    events = ["push"]
}

# Github repository webhook for apis
resource "github_repository_webhook" "apis_github_webhook" {
    repository  = "${data.github_repository.apis_github_repo.name}"

    configuration {
        url             = "${aws_codepipeline_webhook.codepipeline_apis_webhook.url}"
        content_type    = "json"
        insecure_ssl    = false
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

# Default VPC in the current region
data "aws_vpc" "default" {
    default = true
}

# Subnet IDs of the default VPC
data "aws_subnet_ids" "default" {
    vpc_id = "${data.aws_vpc.default.id}"
}

# Default security group under the default VPC
data "aws_security_group" "default" {
    vpc_id = "${data.aws_vpc.default.id}"
    name = "default"
}

resource "aws_security_group" "rds_security_group" {
    name = "allow_rds_mysql"
    description = "Allow inbound traffic for RDS MySQL"
    vpc_id = "${data.aws_vpc.default.id}"

    ingress {
        from_port       = 3306
        to_port         = 3306
        protocol        = "tcp"
        security_groups = ["${data.aws_security_group.default.id}"]
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

# RDS DB
resource "aws_rds_cluster" "db" {
    cluster_identifier = "${local.stack_name_dash}-aurora-cluster"
    engine = "aurora" # (for MySQL 5.6-compatible Aurora)
    engine_mode = "serverless"

    database_name = "${local.stack_name_us}"
    master_username = "admin"
    master_password = "${local.rds_db_password}"

    vpc_security_group_ids = ["${aws_security_group.rds_security_group.id}"]

    scaling_configuration {
        auto_pause = false
    }
}

data "aws_ssm_parameter" "ssm_django_secret_key" {
    name = "/${local.stack_name_us}/django_secret_key"
}

data "aws_ssm_parameter" "rds_db_password" {
    name = "/${local.stack_name_us}/rds_db_password"
}

# Composed database url for backend to use
resource "aws_ssm_parameter" "ssm_full_db_url" {
    name = "/${local.stack_name_us}/full_db_url"
    type = "SecureString"
    description = "Database url used by the Django app"
    value = "mysql://${aws_rds_cluster.db.master_username}:${local.rds_db_password}@${aws_rds_cluster.db.endpoint}:${aws_rds_cluster.db.port}/${aws_rds_cluster.db.database_name}"
}

################################################################################
# Security configurations

# Web Application Firewall for APIs
resource "aws_wafregional_web_acl" "api_web_acl" {
    depends_on = [
        "aws_wafregional_sql_injection_match_set.sql_injection_match_set",
        "aws_wafregional_rule.api_waf_sql_rule"
    ]
    name = "dataPortalAPIWebAcl"
    metric_name = "dataPortalAPIWebAcl"

    default_action {
        type = "ALLOW"
    }

    rule {
        action {
            type = "BLOCK"
        }

        priority    = 1
        rule_id     = "${aws_wafregional_rule.api_waf_sql_rule.id}"
        type        = "REGULAR"
    }
}

# SQL Injection protection
resource "aws_wafregional_rule" "api_waf_sql_rule" {
    depends_on = ["aws_wafregional_sql_injection_match_set.sql_injection_match_set"]
    name = "${local.stack_name_dash}-sql-rule"
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

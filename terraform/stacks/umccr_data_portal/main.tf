################################################################################
# Generic resources

provider "aws" {
    region = "${local.main_region}"
}

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
  secret_id = "${terraform.workspace}/DataPortal"
}

# Secret helper for retrieving value from map (as we dont have jsondecode in v11)
data "external" "secrets_helper" {
  program = ["echo", "${data.aws_secretsmanager_secret_version.secrets.secret_string}"]
}

locals {
    main_region = "ap-southeast-2"
    client_s3_origin_id = "clientS3"
    data_portal_domain_prefix = "data-portal"
    google_app_secret = "${data.external.secrets_helper.result["google_app_secret"]}"
    git_webhook_secret_client = "${data.external.secrets_helper.result["git_webhook_secret_client"]}"
    git_webhook_secret_apis = "${data.external.secrets_helper.result["git_webhook_secret_apis"]}"

    codebuild_project_name_client = "data-portal-client-${terraform.workspace}"
    codebuild_project_name_apis = "data-portal-apis-${terraform.workspace}"

    lims_crawler_target = "s3://${data.aws_s3_bucket.lims_bucket_for_crawler.bucket}"
    s3_keys_crawler_target = "s3://${data.aws_s3_bucket.s3_keys_bucket_for_crawler.bucket}/data"

    api_url = "api.${aws_acm_certificate.client_cert.domain_name}"
} 

################################################################################
# Client configurations

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "client_bucket" {
    bucket  = "umccr-data-portal-client-${terraform.workspace}"
    acl     = "private"

    website {
        index_document = "index.html"
        error_document = "index.html"
    }
}

# Policy document for the client bucket
data "aws_iam_policy_document" "client_bucket_policy_document" {
    statement {
        actions   = ["s3:GetObject"]
        resources = ["${aws_s3_bucket.client_bucket.arn}/*"]

        principals {
            type        = "AWS"
            identifiers = ["${aws_cloudfront_origin_access_identity.client_origin_access_identity.iam_arn}"]
        }
    }

    statement {
        # Alow access for the origin access identity to index.html
        actions   = ["s3:ListBucket"]
        resources = ["${aws_s3_bucket.client_bucket.arn}"]

        principals {
            type        = "AWS"
            identifiers = ["${aws_cloudfront_origin_access_identity.client_origin_access_identity.iam_arn}"]
        }
    }
}

# Attach the policy to the client bucket
resource "aws_s3_bucket_policy" "client_bucket_policy" {
    bucket = "${aws_s3_bucket.client_bucket.id}"
    policy = "${data.aws_iam_policy_document.client_bucket_policy_document.json}"
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
    aliases                 = ["data-portal.dev.umccr.org"]
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
    domain_name         = "${local.data_portal_domain_prefix}.${var.org_domain[terraform.workspace]}"
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
    domain_name         = "*.${local.data_portal_domain_prefix}.${var.org_domain[terraform.workspace]}"
    validation_method   = "DNS"

    lifecycle {
        create_before_destroy = true
    }
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

resource "aws_iam_role" "glue_service_role" {
    name = "AWSGlueServiceRole-Data-Portal"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "glue.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

# Attach the default policy to the glue service role
resource "aws_iam_role_policy_attachment" "glue_service_role_attach_default" {
    role = "${aws_iam_role.glue_service_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_policy" "glue_service_role_policy" {
    name = "AWSGlueServiceRole-Data-Portal"
    description = "IAM policy for data portal glue service role"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": [
                "${data.aws_s3_bucket.lims_bucket_for_crawler.arn}/*",
                "${data.aws_s3_bucket.s3_keys_bucket_for_crawler.arn}/*"
            ]
        }
    ]
}
EOF
}

# Attach specific policy to the service role
resource "aws_iam_role_policy_attachment" "glue_service_role_attach_specific" {
    role        = "${aws_iam_role.glue_service_role.name}"
    policy_arn  = "${aws_iam_policy.glue_service_role_policy.arn}"
}


# S3 buckets for Glue crawler
data "aws_s3_bucket" "s3_keys_bucket_for_crawler" {
    bucket = "${var.s3_keys_bucket_for_crawler[terraform.workspace]}"
}

data "aws_s3_bucket" "lims_bucket_for_crawler" {
    bucket = "${var.lims_bucket_for_crawler[terraform.workspace]}"
}

# # The bucket to store athena query results
resource "aws_s3_bucket" "athena_results_s3" {
    bucket  = "umccr-athena-query-results-${terraform.workspace}"
    acl     = "private"
}

# Glue crawlers
resource "aws_glue_crawler" "glue_crawler_s3" {
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"
    name            = "data_portal_${terraform.workspace}_s3_keys_crawler"
    role            = "${aws_iam_role.glue_service_role.arn}"

    s3_target {
        path = "${local.s3_keys_crawler_target}"
    }

    # Prevent the crawler from changing our preset schema
    schema_change_policy {
        update_behavior = "LOG"
    }

    configuration = <<EOF
{
   "Version": 1.0,
   "CrawlerOutput": {
       "Partitions": { "AddOrUpdateBehavior": "InheritFromTable" }
   }
}
EOF
}

resource "aws_glue_crawler" "glue_crawler_lims" {
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"
    name            = "data_portal_${terraform.workspace}_lims_crawler"
    role            = "${aws_iam_role.glue_service_role.arn}"

    s3_target {
        path ="${local.lims_crawler_target}"
    }

    # Prevent the crawler from changing our preset schema
    schema_change_policy {
        update_behavior = "LOG"
    }

    configuration = <<EOF
{
   "Version": 1.0,
   "CrawlerOutput": {
       "Partitions": { "AddOrUpdateBehavior": "InheritFromTable" }
   }
}
EOF
}

# Glue catalog database
resource "aws_glue_catalog_database" "glue_catalog_db" {
    name = "data_portal_${terraform.workspace}"
}

resource "aws_glue_catalog_table" "glue_catalog_tb_s3" {
    name            = "data"
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"
    description     = "Table storing crawled data from s3 file keys"

    storage_descriptor {
        # Use the same location as the crawler target
        location        = "${local.s3_keys_crawler_target}/"
        input_format    = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
        output_format   = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

        ser_de_info {
            name = "parquet"
            serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

            parameters = {
                "serialization.format" = 1
            }
        }

        columns {
            name = "bucket"
            type = "string"
        }

        columns {
            name = "key"
            type = "string"
        }

        columns {
            name = "size"
            type = "bigint"
        }

        columns {
            name = "last_modified_date"
            type = "timestamp"
        }

        columns {
            name = "e_tag"
            type = "string"
        }

        columns {
            name = "storage_class"
            type = "string"
        }

        columns {
            name = "encryption_status"
            type = "string"
        }
    }
}

resource "aws_glue_catalog_table" "glue_catalog_tb_lims" {
    name            = "${replace(data.aws_s3_bucket.lims_bucket_for_crawler.bucket, "-", "_")}"
    database_name   =  "${aws_glue_catalog_database.glue_catalog_db.name}"
    description     = "Table storing crawled data from LIMS spreadsheet"

    storage_descriptor {
        # Use the same location as the crawler target
        location        = "${local.lims_crawler_target}/"
        input_format    = "org.apache.hadoop.mapred.TextInputFormat"
        output_format   = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

        ser_de_info {
            name = "csv"
            serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

            parameters = {
                "skip.header.line.count"    = 1
                "field.delim"               = ","
            }
        }

        columns {
            name = "illumina_id"
            type = "string"
        }

        columns {
            name = "run"
            type = "string"
        }   

        columns {
            name = "timestamp"
            type = "string"
        }   

        columns {
            name = "sampleid"
            type = "string"
        }   

        columns {
            name = "samplename"
            type = "string"
        }   

        columns {
            name = "project"
            type = "string"
        }   

        columns {
            name = "subjectid"
            type = "string"
        }

        columns {
            name = "type"
            type = "string"
        }

        columns {
            name = "phenotype"
            type = "string"
        }

        columns {
            name = "source"
            type = "string"
        }

        columns {
            name = "quality"
            type = "string"
        }

        columns {
            name = "secondary analysis"
            type = "string"
        }

        columns {
            name = "fastq"
            type = "string"
        }

        columns {
            name = "number fastqs"
            type = "string"
        }

        columns {
            name = "results"
            type = "string"
        }

        columns {
            name = "trello"
            type = "string"
        }

        columns {
            name = "notes"
            type = "string"
        }

        columns {
            name = "todo"
            type = "string"
        }
    }
}

# Cognito
resource "aws_cognito_user_pool" "user_pool" {
    name = "data-portal-${terraform.workspace}"
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
resource "aws_iam_role" "role_authenticated" {
    name = "data_portal_${terraform.workspace}_authenticated"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "cognito-identity.amazonaws.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.identity_pool.id}"
                },
                "ForAnyValue:StringLike": {
                    "cognito-identity.amazonaws.com:amr": "authenticated"
                }
            }
        }
    ]
}
EOF
}

# IAM role policy for authenticated identities
resource "aws_iam_role_policy" "role_policy_authenticated" {
    name = "authenticated_policy"
    role = "${aws_iam_role.role_authenticated.id}"

    # Todo: we should have a explicit reference to our api
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "mobileanalytics:PutEvents",
                "cognito-sync:*",
                "cognito-identity:*"
            ],
            "Resource": [
                "*"
            ]
        },
        {
           "Effect": "Allow",
            "Action": [
                "execute-api:Invoke"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
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
    name                                    = "data-portal-app-${terraform.workspace}"
    user_pool_id                            = "${aws_cognito_user_pool.user_pool.id}"
    supported_identity_providers            = ["Google"]

    callback_urls                           = ["https://${local.data_portal_domain_prefix}.${var.org_domain[terraform.workspace]}"]
    logout_urls                             = ["https://${local.data_portal_domain_prefix}.${var.org_domain[terraform.workspace]}"]

    generate_secret                         = false

    allowed_oauth_flows                     = ["code"]
    allowed_oauth_flows_user_pool_client    = true
    allowed_oauth_scopes                    = ["email", "openid", "aws.cognito.signin.user.admin", "profile"]
    explicit_auth_flows                     = ["ADMIN_NO_SRP_AUTH"]

    # Need to explicitly specify this dependency
    depends_on                              = ["aws_cognito_identity_provider.identity_provider"]
}

# User pool client (localhost access)
resource "aws_cognito_user_pool_client" "user_pool_client_localhost" {
    name                                    = "data-portal-app-${terraform.workspace}-localhost"
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
    domain          = "data-portal-app-${terraform.workspace}"
    user_pool_id    = "${aws_cognito_user_pool.user_pool.id}"
}

################################################################################
# Deployment pipeline configurations

# Bucket storing codepipeline artifacts (both client and apis)
resource "aws_s3_bucket" "codepipeline_bucket" {
    bucket  = "data-portal-codepipeline-artifacts"
    acl     = "private"
}

# Base IAM role for codepipeline service
resource "aws_iam_role" "codepipeline_base_role" {
    name = "codepipeline-data-portal-base-role"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Base IAM policy for codepiepline service role
resource "aws_iam_role_policy" "codepipeline_base_policy" {
    name = "codepipeline-data-portal-base-policy"
    role = "${aws_iam_role.codepipeline_base_role.id}"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect":"Allow",
        "Action": [
            "s3:*"
        ],
        "Resource": [
            "${aws_s3_bucket.codepipeline_bucket.arn}",
            "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ]
        },
        {
        "Effect": "Allow",
        "Action": [
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild"
        ],
        "Resource": "*"
        }
    ]
}
EOF
}

# Codepipeline for client
resource "aws_codepipeline" "codepipeline_client" {
    name        = "data-portal-client-${terraform.workspace}"
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
                Owner   = "umccr"
                Repo    = "data-portal-client"
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
    name        = "data-portal-apis-${terraform.workspace}"
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
                Owner   = "umccr"
                Repo    = "data-portal-apis"
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
resource "aws_iam_role" "codebuild_client_iam_role" {
    name = "codebuild-data-portal-client-service-role"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "codebuild.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

# IAM role for code build (client)
resource "aws_iam_role" "codebuild_apis_iam_role" {
    name = "codebuild-data-portal-apis-service-role"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

# IAM policy specific for the apis side 
resource "aws_iam_policy" "codebuild_apis_iam_policy" {
    name = "codebuild-data-portal-apis-service-policy"
    description = "Policy for CodeBuild for backend side of data portal"

    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:*",
                "athena:*",
                "cloudformation:*",
                "iam:*",
                "lambda:*",
                "apigateway:POST",                
                "apigateway:DELETE",
                "apigateway:PATCH",
                "apigateway:GET",
                "apigateway:PUT",
                "acm:*",
                "route53:*"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

# Attach the base policy to the code build role for client
resource "aws_iam_role_policy_attachment" "codebuild_client_iam_role_attach_base_policy" {
    role        = "${aws_iam_role.codebuild_client_iam_role.name}"
    policy_arn  = "${aws_iam_policy.codebuild_base_iam_policy.arn}"
}

# Attach the base policy to the code build role for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_iam_role_attach_base_policy" {
    role        = "${aws_iam_role.codebuild_apis_iam_role.name}"
    policy_arn  = "${aws_iam_policy.codebuild_base_iam_policy.arn}"
}

# Attach specific policies to the code build ro for apis
resource "aws_iam_role_policy_attachment" "codebuild_apis_iam_role_attach_specific_policy" {
    role        = "${aws_iam_role.codebuild_apis_iam_role.name}"
    policy_arn  = "${aws_iam_policy.codebuild_apis_iam_policy.arn}"
}


# Base IAM policy for code build
resource "aws_iam_policy" "codebuild_base_iam_policy" {
    name = "codebuild-data-portal-base-service-policy"
    description = "Base policy for CodeBuild for data portal site"

    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Resource": [
            "*"
        ],
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        },
        {
        "Effect": "Allow",
        "Action": [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeVpcs"
        ],
        "Resource": "*"
        },
        {
        "Effect": "Allow",
        "Action": [
            "s3:*"
        ],
        "Resource": "*"
        }
    ]
}
POLICY
}

# Codebuild project for client
resource "aws_codebuild_project" "codebuild_client" {
    name = "${local.codebuild_project_name_client}"
    service_role = "${aws_iam_role.codebuild_client_iam_role.arn}"

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
            value = "${local.api_url}"
        }

        environment_variable {
            name  = "REGION"
            value = "${local.main_region}"
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
        location = "https://github.com/umccr/data-portal-client.git"
        git_clone_depth = 1
    }
}

# Codebuild project for apis
resource "aws_codebuild_project" "codebuild_apis" {
    name = "${local.codebuild_project_name_apis}"
    service_role = "${aws_iam_role.codebuild_apis_iam_role.arn}"

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
            value = "${local.api_url}"
        }

        environment_variable {
            name  = "ATHENA_OUTPUT_LOCATION"
            value = "s3://${aws_s3_bucket.athena_results_s3.bucket}" 
        }

        # The table name is determined by the corresponding glue catelog table
        environment_variable {
            name  = "S3_KEYS_TABLE_NAME"
            value = "${aws_glue_catalog_table.glue_catalog_tb_s3.database_name}.${aws_glue_catalog_table.glue_catalog_tb_s3.name}"
        }

        # The table name is determined by the corresponding glue catelog table
        environment_variable {
            name  = "LIMS_TABLE_NAME"
            value = "${aws_glue_catalog_table.glue_catalog_tb_lims.database_name}.${aws_glue_catalog_table.glue_catalog_tb_lims.name}"
        }
    }

    source {
        type = "GITHUB"
        location = "https://github.com/umccr/data-portal-apis.git"
        git_clone_depth = 1
    }
}

# Codepipeline webhook for client code repository
resource "aws_codepipeline_webhook" "codepipeline_client_webhook" {
    name            = "webhook-github-client"
    authentication  = "GITHUB_HMAC"
    target_action   = "Source"
    target_pipeline = "${aws_codepipeline.codepipeline_client.name}"

    authentication_configuration {
        secret_token = "${local.git_webhook_secret_client}"
    }

    filter {
        json_path       = "$.ref"
        match_equals    = "refs/heads/{Branch}"
    }
}

# Codepipeline webhook for apis code repository
resource "aws_codepipeline_webhook" "codepipeline_apis_webhook" {
    name            = "webhook-github-apis"
    authentication  = "GITHUB_HMAC"
    target_action   = "Source"
    target_pipeline = "${aws_codepipeline.codepipeline_apis.name}"

    authentication_configuration {
        secret_token = "${local.git_webhook_secret_apis}"
    }

    filter {
        json_path       = "$.ref"
        match_equals    = "refs/heads/{Branch}"
    }
}

# Github repository of client
data "github_repository" "client_github_repo" {
    full_name = "umccr/data-portal-client"
}

# Github repository of apis
data "github_repository" "apis_github_repo" {
    full_name = "umccr/data-portal-apis"
}

# Github repository webhook for client
resource "github_repository_webhook" "client_github_webhook" {
    repository  = "${data.github_repository.client_github_repo.name}"

    configuration {
        url             = "${aws_codepipeline_webhook.codepipeline_client_webhook.url}"
        content_type    = "json"
        insecure_ssl    = false
        secret          = "${local.git_webhook_secret_client}"
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
        secret          = "${local.git_webhook_secret_apis}"
    }

    events = ["push"]
}
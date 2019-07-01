################################################################################
# Generic resources

provider "aws" {
    region = "ap-southeast-2"
}

locals {
    client_s3_origin_id = "clientS3"
    data_portal_domain_prefix = "data-portal"
} 

data "aws_secretsmanager_secret_version" "secrets" {
  secret_id = "${terraform.workspace}/DataPortal"
}

################################################################################
# Client configurations

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "client_bucket" {
    bucket  = "umccr-data-portal-${terraform.workspace}"
    acl     = "private"

    website {
        index_document = "index.html"
        error_document = "index.html"
    }
}

# CloudFront layer for client S3 bucket access
resource "aws_cloudfront_distribution" "client_distribution" {
    origin {
        domain_name = "${aws_s3_bucket.client_bucket.bucket_regional_domain_name}"
        origin_id   = "${local.client_s3_origin_id}"
    }

    enabled = true
    aliases = ["data-portal.dev.umccr.org"]
    viewer_certificate {
        acm_certificate_arn = "${aws_acm_certificate.client_cert.arn}"
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
}

# Hosted zone for organisation domain
data "aws_route53_zone" "org_zone" {
    name = "${var.org_domain[terraform.workspace]}."
}

data "aws_elb_hosted_zone_id" "main" {}

# Alias the client domain name to CloudFront distribution address
resource "aws_route53_record" "client_alias" {
    zone_id = "${data.aws_route53_zone.org_zone.zone_id}"
    name = "${local.data_portal_domain_prefix}.${data.aws_route53_zone.org_zone.name}"
    type = "A"
    alias {
        name                    = "${aws_cloudfront_distribution.client_distribution.domain_name}"
        zone_id                 = "${data.aws_elb_hosted_zone_id.main.id}"
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
    domain_name         = "${local.data_portal_domain_prefix}.${var.org_domain[terraform.workspace]}"
    validation_method   = "DNS"

    lifecycle {
        create_before_destroy = true
    }
}

# Certificate validation for client domain
resource "aws_acm_certificate_validation" "client_cert_dns" {
    certificate_arn = "${aws_acm_certificate.client_cert.arn}"
    validation_record_fqdns = ["${aws_route53_record.client_cert_validation.fqdn}"]
}

################################################################################
# Back end configurations
resource "aws_iam_role" "glue_service_role" {
    name = "AWSGlueServiceRole-Data-Portal"

    assume_role_policy = <<EOF
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
                "arn:aws:s3:::umccr-inventory-dev/*",
                "arn:aws:s3:::umccr-primary-data-dev/*",
                "arn:aws:s3:::umccr-data-google-lims-dev/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_service_role_attach" {
    role = "${aws_iam_role.glue_service_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# S3 buckets for Glue crawler
data "aws_s3_bucket" "s3_keys_bucket_for_crawler" {
    bucket = "${var.s3_keys_bucket_for_crawler[terraform.workspace]}"
}

data "aws_s3_bucket" "lims_bucket_for_crawler" {
    bucket = "${var.lims_bucket_for_crawler[terraform.workspace]}"
}

# The bucket to store athena query results
resource "aws_s3_bucket" "athena_results_s3" {
    bucket  = "umccr-athena-query-results-${terraform.workspace}"
    acl     = "private"
}

# Athena database
resource "aws_athena_database" "athena_db" {
    name    = "data_portal_${terraform.workspace}"
    bucket  = "${aws_s3_bucket.athena_results_s3.bucket}"

    encryption_configuration {
        encryption_option = "SSE_S3"
    }
}

# Glue crawlers
resource "aws_glue_crawler" "glue_crawler_s3" {
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"
    name            = "s3_keys_crawler"
    role            = "${aws_iam_role.glue_service_role.arn}"

    s3_target {
        path = "s3://${data.aws_s3_bucket.s3_keys_bucket_for_crawler.id}"
    }
}

resource "aws_glue_crawler" "glue_crawler_lims" {
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"
    name            = "lims_crawler"
    role            = "${aws_iam_role.glue_service_role.arn}"

    s3_target {
        path = "s3://${data.aws_s3_bucket.lims_bucket_for_crawler.id}"
    }
}

# Glue catalog database
resource "aws_glue_catalog_database" "glue_catalog_db" {
    name = "data_portal_${terraform.workspace}"
}

resource "aws_glue_catalog_table" "glue_catalog_tb_s3" {
    name            = "s3_keys"
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"

    storage_descriptor {
        location        = "s3://${data.aws_s3_bucket.s3_keys_bucket_for_crawler.id}"
        input_format    = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
        output_format   = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

        ser_de_info {
            name = "parquet"
            serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

            parameters = {
                "serialization.format" = 1
            }
        }
    }
}

resource "aws_glue_catalog_table" "glue_catalog_tb_lims" {
    name            = "lims"
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"

    storage_descriptor {
        location        = "s3://${data.aws_s3_bucket.lims_bucket_for_crawler.id}"
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
        client_secret       = "${lookup(jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string),"google_app_secret")}"
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

# User pool client
resource "aws_cognito_user_pool_client" "user_pool_client" {
    name                                    = "data-portal-app-${terraform.workspace}"
    user_pool_id                            = "${aws_cognito_user_pool.user_pool.id}"
    supported_identity_providers            = ["Google"]

    callback_urls                           = ["https://${local.data_portal_domain_prefix}.${var.org_domain[terraform.workspace]}"]
    logout_urls                             = ["https://${local.data_portal_domain_prefix}.${var.org_domain[terraform.workspace]}"]

    allowed_oauth_flows                     = ["code"]
    allowed_oauth_flows_user_pool_client    = true
    allowed_oauth_scopes                    = ["email", "openid", "aws.cognito.signin.user.admin", "profile"]
}

# User pool client (localhost access)
resource "aws_cognito_user_pool_client" "user_pool_client_localhost" {
    name                                    = "data-portal-app-${terraform.workspace}-localhost"
    user_pool_id                            = "${aws_cognito_user_pool.user_pool.id}"
    supported_identity_providers            = ["Google"]

    callback_urls                           = ["http://localhost:3000"]
    logout_urls                             = ["http://localhost:3000"]

    allowed_oauth_flows                     = ["code"]
    allowed_oauth_flows_user_pool_client    = true
    allowed_oauth_scopes                    = ["email", "openid", "aws.cognito.signin.user.admin", "profile"]
}
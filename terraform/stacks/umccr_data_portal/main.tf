provider "aws" {
    region = "ap-southeast-2"
}


locals {
  client_s3_origin_id = "clientS3"
  data_portal_domain_prefix = "data-portal"
}


################################################################################
# Client configurations

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "client_bucket" {
    bucket  = "umccr_data_portal_${var.stage}"
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

        path_pattern            = "*"
        viewer_protocol_policy  = "redirect-to-https"
    }
}

# Hosted zone for organisation domain
data "aws_route53_zone" "org_zone" {
    name = "${var.org_domain}."
}

# Alias the client domain name to CloudFront distribution address
resource "aws_route53_record" "client_alias" {
    name = "${local.data_portal_domain_prefix}.${data.aws_route53_zone.org_zone.name}"
    type = "A"
    alias = "${aws_cloudfront_distribution.client_distribution.domain_name}"
}

# Client certificate validation through a Route53 record
resource "aws_route53_record" "client_cert_validation" {
    name    = "${aws_acm_certificate.client_cert.domain_validation_options.0.resource_record_name}"
    type    = "${aws_acm_certificate.client_cert.domain_validation_options.0.resource_record_type}"
    zone_id = "${data.aws_route53_zone.org_zone.zone.id}"
    records = ["${aws_acm_certificate.client_cert.domain_validation_options.0.resource_record_value}"]
    ttl     = 300
}

# The certificate for client domain, validating using DNS
resource "aws_acm_certificate" "client_cert" {
    domain_name         = "${local.data_portal_domain_prefix}.${var.org_domain}"
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
}


# Athena database
resource "aws_athena_database" "athena_db" {
    name = "data_portal_${var.stage}"
}

# Glue crawler
resource "aws_glue_crawler" "glue_crawler_s3" {
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"
    name            = "s3_keys_crawler"
    role            = "" # todo
}

resource "aws_glue_crawler" "glue_crawler_lims" {
    database_name   = "${aws_glue_catalog_database.glue_catalog_db.name}"
    name            = "lims_crawler"
    role            = "" # todo
}


# Glue catalog database
resource "aws_glue_catalog_database" "glue_catalog_db" {
    name = "data_portal_${var.stage}"
}

resource "aws_glue_catalog_table" "glue_catalog_tb_s3" {
    name            = "s3_keys"
    database_name   = "${aws_glue_catalog_database.glue_catelog_db.name}"

    storage_descriptor {
        location        = "" # todo
        input_format    = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
        output_format   = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

        ser_de_info {
            name = "parquet"
            serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

            parameters = {
                "skip.header.line.count"    = 1
                "field.delim"               = ","
            }
        }
    }
}

resource "aws_glue_catalog_table" "glue_catalog_tb_lims" {
    name            = "lims"
    database_name   = "${aws_glue_catalog_database.glue_catelog_db.name}"

    storage_descriptor {
        location        = "" # todo
        input_format    = "org.apache.hadoop.mapred.TextInputFormat"
        output_format   = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

        ser_de_info {
            name = "csv"
            serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

            parameters = {
                "serialization.format" = 1
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
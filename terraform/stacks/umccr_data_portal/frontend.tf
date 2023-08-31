################################################################################
# Client configurations

locals {
  client_s3_origin_id = "clientS3"

  cert_domain_name = {
    prod = local.app_domain
    dev  = local.app_domain2
    stg  = local.app_domain2
  }

  cert_subject_alt_names = {
    prod = sort(["*.${local.app_domain}", var.alias_domain[terraform.workspace]])
    dev  = sort(["*.${local.app_domain2}"])
    stg  = sort(["*.${local.app_domain2}"])
  }

  cloudfront_domain_aliases = {
    prod = [local.app_domain, var.alias_domain[terraform.workspace]]
    dev  = [local.app_domain2]
    stg  = [local.app_domain2]
  }
}

# S3 bucket storing client side (compiled) code
resource "aws_s3_bucket" "client_bucket" {
  bucket = "${local.org_name}-${local.stack_name_dash}-client-${terraform.workspace}"
  tags   = merge(local.default_tags)
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

# Alias the client domain name to CloudFront distribution address
resource "aws_route53_record" "client_alias" {
  zone_id = data.aws_route53_zone.org_zone.zone_id
  name    = "${local.cert_domain_name[terraform.workspace]}."
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
  for dvo in aws_acm_certificate.client_cert.domain_validation_options : dvo.domain_name => {
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
  domain_name       = local.cert_domain_name[terraform.workspace]
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

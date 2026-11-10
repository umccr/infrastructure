################################################################################
# TLS certificate for the docs CloudFront distribution

resource "aws_acm_certificate" "docs" {
  # Certificate needs to be US Virginia region in order to be used by cloudfront distribution
  provider          = aws.use1
  domain_name       = local.docs_domain
  validation_method = "DNS"

  subject_alternative_names = compact([local.docs_alias_domain])

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags)
}

# Validation record for the stage hostname, in this account's stage zone.
#
# The alias hostname (docs.umccr.org) validates in the umccr.org zone, which is managed in another account, so its
# record is not created here. The `umccr_org_zone_records` output lists what to add there.
resource "aws_route53_record" "docs_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.docs.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    } if dvo.domain_name == local.docs_domain
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = 60
  zone_id         = data.aws_route53_zone.stage_zone.zone_id
}

# Wait for the certificate only where every name validates in the stage zone.
#
# In prod the certificate stays pending until the docs.umccr.org validation record exists in the umccr.org zone. ACM
# issues it on its own once that record resolves; deploy the prod hosting stack only after that. See README.
resource "aws_acm_certificate_validation" "docs" {
  count = local.docs_alias_domain == "" ? 1 : 0

  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.docs.arn
  validation_record_fqdns = [for record in aws_route53_record.docs_cert_validation : record.fqdn]
}

################################################################################
# Save configurations in SSM Parameter Store

# Read by the docs hosting stack, UMCCR-DocsHostingStack in umccr/docs-platform, at deploy time, the same way the
# portal reads /orcaui/certificate_arn. The parameter is in ap-southeast-2; the certificate itself is in us-east-1.
resource "aws_ssm_parameter" "docs_certificate_arn" {
  name  = "/docs/certificate_arn"
  type  = "String"
  value = aws_acm_certificate.docs.arn
  tags  = merge(local.default_tags)
}

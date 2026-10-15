output "docs_domain" {
  value = local.docs_domain
}

output "docs_certificate_arn" {
  value = aws_acm_certificate.docs.arn
}

# Records to add to the umccr.org zone by hand, in prod only: the certificate validation record for docs.umccr.org,
# and docs.umccr.org as a CNAME of the prod stage hostname. Empty in dev and stg.
output "umccr_org_zone_records" {
  value = local.docs_alias_domain == "" ? [] : concat(
    [
      for dvo in aws_acm_certificate.docs.domain_validation_options : {
        name  = dvo.resource_record_name
        type  = dvo.resource_record_type
        value = dvo.resource_record_value
      } if dvo.domain_name == local.docs_alias_domain
    ],
    [
      {
        name  = "${local.docs_alias_domain}."
        type  = "CNAME"
        value = "${local.docs_domain}."
      }
    ]
  )
}

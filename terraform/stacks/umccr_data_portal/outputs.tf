output "main_region" {
  value = data.aws_region.current.name
}

output "api_domain" {
  value = local.api_domain
}

# FIXME: https://github.com/umccr/infrastructure/issues/272
output "api_domain2" {
  value = local.api_domain2
}

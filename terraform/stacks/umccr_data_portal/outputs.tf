output "main_region" {
  value = data.aws_region.current.name
}

output "api_domain" {
  value = local.api_domain
}

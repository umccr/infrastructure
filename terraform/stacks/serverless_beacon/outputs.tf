output "workspace" {
  value = "${terraform.workspace}"
}

output "beacon_api_url" {
  value = "${module.serverless_beacon.api_url}"
}

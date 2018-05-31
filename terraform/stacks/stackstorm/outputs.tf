output "workspace" {
  value = "${terraform.workspace}"
}

output "stackstorm_public_ip" {
  value = "${module.stackstorm.stackstorm_eip_public_ip}"
}

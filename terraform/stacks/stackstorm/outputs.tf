output "stackstorm_prod_public_ip" {
  value = "${module.stackstorm.stackstorm_eip_public_ip}"
}

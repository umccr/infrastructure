output "stackstorm_dev_public_ip" {
  value = "${module.stackstorm.stackstorm_eip_public_ip}"
}

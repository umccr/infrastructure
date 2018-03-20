output "stackstorm_username" {
  value = "${module.stackstorm_user.username}"
}
output "stackstorm_access_key" {
  value = "${module.stackstorm_user.access_key}"
}
output "stackstorm_secret_access_key" {
  value = "${module.stackstorm_user.secret_access_key}"
}

output "stackstorm_eip_public_ip" {
  value = "${aws_eip.stackstorm.public_ip}"
}

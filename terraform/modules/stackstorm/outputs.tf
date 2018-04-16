output "stackstorm_eip_public_ip" {
  value = "${aws_eip.stackstorm.public_ip}"
}

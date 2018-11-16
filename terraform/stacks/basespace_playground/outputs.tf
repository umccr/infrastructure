output "environment" {
  value = "${var.deploy_env}"
}

output "instance_static_IP" {
  value = "${data.aws_eip.eip_by_tag.public_ip}"
}

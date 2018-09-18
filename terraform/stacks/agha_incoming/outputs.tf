output "workspace" {
  value = "${terraform.workspace}"
}

output "instance_tags" {
  value = "${jsonencode(var.workspace_instance_tags[terraform.workspace])}"
}

output "instance_public_dns" {
  value = "${aws_spot_instance_request.stackstorm_instance.public_dns}"
}

output "instance_public_ip" {
  value = "${aws_spot_instance_request.stackstorm_instance.public_ip}"
}
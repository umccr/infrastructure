output "instance_tags" {
  value = "${jsonencode(var.instance_tags)}"
}

output "instance_public_dns" {
  value = "${aws_spot_instance_request.agha_instance.public_dns}"
}

output "instance_public_ip" {
  value = "${aws_spot_instance_request.agha_instance.public_ip}"
}

output "instance_id" {
  value = "${aws_spot_instance_request.agha_instance.spot_instance_id}"
}

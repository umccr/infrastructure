output "workspace" {
  value = "${terraform.workspace}"
}

output "instance_tags" {
  value = "${jsonencode(var.workspace_instance_tags[terraform.workspace])}"
}
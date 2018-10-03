output "workspace" {
  value = "${terraform.workspace}"
}

output "vault_eip_public_ip" {
  value = "${aws_eip.vault.public_ip}"
}

output "slack_notify_lambda_arn" {
  value = "${module.notify_slack_lambda.function_arn}"
}
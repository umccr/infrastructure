output "console_user_key_ids" {
  value = "${module.console_users.access_keys}"
}

output "console_user_secure_keys" {
  value = "${module.console_users.encrypted_secret_access_keys}"
}

output "console_user_logins" {
  value = "${zipmap(aws_iam_user_login_profile.console_user_login.*.user, aws_iam_user_login_profile.console_user_login.*.encrypted_password)}"
}

output "service_user_key_ids" {
  value = "${module.service_users.access_keys}"
}

output "service_user_secure_keys" {
  value = "${module.service_users.encrypted_secret_access_keys}"
}

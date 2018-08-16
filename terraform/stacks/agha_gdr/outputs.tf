output "user_key_ids" {
  value = "${module.users.access_keys}"
}

output "user_secure_keys" {
  value = "${module.users.encrypted_secret_access_keys}"
}

output "user_logins" {
  value = "${zipmap(aws_iam_user_login_profile.users_login.*.user, aws_iam_user_login_profile.users_login.*.encrypted_password)}"
}

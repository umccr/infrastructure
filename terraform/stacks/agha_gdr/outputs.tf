# output user details

# rk_chw
output "rk_chw_username" {
  value = "${module.rk_chw.username}"
}

output "rk_chw_access_key" {
  value = "${module.rk_chw.access_key}"
}

output "rk_chw_secret_access_key" {
  value = "${module.rk_chw.encrypted_secret_access_key}"
}


# sarah
output "sarah_username" {
  value = "${module.sarah.username}"
}

output "sarah_access_key" {
  value = "${module.sarah.access_key}"
}

output "sarah_secret_access_key" {
  value = "${module.sarah.encrypted_secret_access_key}"
}

output "sarah_console_login" {
  value = "${aws_iam_user_login_profile.sarah_console_login.encrypted_password}"
}


# output for serivce user: agha_bot_user
output "agha_bot_user_username" {
  value = "${module.agha_bot_user.username}"
}

output "agha_bot_user_access_key" {
  value = "${module.agha_bot_user.access_key}"
}

output "agha_bot_user_secret_access_key" {
  value = "${module.agha_bot_user.encrypted_secret_access_key}"
}

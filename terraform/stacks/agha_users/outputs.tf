# agha_bot
# output "agha_bot_username" {
#   value = "${module.agha_bot.username}"
# }

# output "agha_bot_access_key" {
#   value = "${module.agha_bot.access_key}"
# }

# output "agha_bot_secret_access_key" {
#   value = "${module.agha_bot.encrypted_secret_access_key}"
# }

# foobar
output "foobar_username" {
  value = module.foobar.username
}

output "foobar_access_key" {
  value = module.foobar.access_key
}

output "foobar_secret_access_key" {
  value = module.foobar.encrypted_secret_access_key
}

output "foobar_console_login" {
  value = aws_iam_user_login_profile.foobar.encrypted_password
}

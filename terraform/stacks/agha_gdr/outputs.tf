# output "user_key_ids" {
#   value = "${module.users.access_keys}"
# }

# output "user_secure_keys" {
#   value = "${module.users.encrypted_secret_access_keys}"
# }

# output "user_logins" {
#   value = "${zipmap(aws_iam_user_login_profile.users_login.*.user, aws_iam_user_login_profile.users_login.*.encrypted_password)}"
# }


# output for serivce user: agha_bot_user
# output "agha_bot_user_username" {
#   value = "${module.agha_bot_user.username}"
# }

# output "agha_bot_user_access_key" {
#   value = "${module.agha_bot_user.access_key}"
# }

# output "uagha_bot_user_secret_access_key" {
#   value = "${module.agha_bot_user.encrypted_secret_access_key}"
# }

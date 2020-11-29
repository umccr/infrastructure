# agha_presign
output "agha_presign_username" {
  value = "${module.agha_presign.username}"
}

output "agha_presign_access_key" {
  value = "${module.agha_presign.access_key}"
}

output "agha_presign_secret_access_key" {
  value = "${module.agha_presign.encrypted_secret_access_key}"
}

# sarah_dm
output "sarah_dm_username" {
  value = module.sarah_dm.username
}

output "sarah_dm_access_key" {
  value = module.sarah_dm.access_key
}

output "sarah_dm_secret_access_key" {
  value = module.sarah_dm.encrypted_secret_access_key
}

output "sarah_dm_console_login" {
  value = aws_iam_user_login_profile.sarah_dm.encrypted_password
}

# simon
output "simon_username" {
  value = module.simon.username
}

output "simon_access_key" {
  value = module.simon.access_key
}

output "simon_secret_access_key" {
  value = module.simon.encrypted_secret_access_key
}

# shyrav
output "shyrav_username" {
  value = module.shyrav.username
}

output "shyrav_access_key" {
  value = module.shyrav.access_key
}

output "shyrav_secret_access_key" {
  value = module.shyrav.encrypted_secret_access_key
}

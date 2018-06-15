output "florian_username" {
  value = "${module.florian_user.username}"
}
output "florian_access_key" {
  value = "${module.florian_user.access_key}"
}
output "florian_secret_access_key" {
  value = "${module.florian_user.encrypted_secret_access_key}"
}

output "brainstorm_username" {
  value = "${module.brainstorm_user.username}"
}
output "brainstorm_access_key" {
  value = "${module.brainstorm_user.access_key}"
}
output "brainstorm_secret_access_key" {
  value = "${module.brainstorm_user.encrypted_secret_access_key}"
}

output "oliver_username" {
  value = "${module.oliver_user.username}"
}
output "oliver_access_key" {
  value = "${module.oliver_user.access_key}"
}
output "oliver_secret_access_key" {
  value = "${module.oliver_user.encrypted_secret_access_key}"
}

output "packer_username" {
  value = "${module.packer_user.username}"
}
output "packer_access_key" {
  value = "${module.packer_user.access_key}"
}
output "packer_secret_access_key" {
  value = "${module.packer_user.encrypted_secret_access_key}"
}

output "terraform_username" {
  value = "${module.terraform_user.username}"
}
output "terraform_access_key" {
  value = "${module.terraform_user.access_key}"
}
output "terraform_secret_access_key" {
  value = "${module.terraform_user.encrypted_secret_access_key}"
}

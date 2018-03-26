output "stackstorm_username" {
  value = "${module.travis_user.username}"
}
output "stackstorm_access_key" {
  value = "${module.travis_user.access_key}"
}
output "stackstorm_secret_access_key" {
  value = "${module.travis_user.encrypted_secret_access_key}"
}

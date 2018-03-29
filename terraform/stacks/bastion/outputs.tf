output "florian_username" {
  value = "${module.florian_user.username}"
}
output "florian_access_key" {
  value = "${module.florian_user.access_key}"
}
output "florian_secret_access_key" {
  value = "${module.florian_user.encrypted_secret_access_key}"
}

output "travis_username" {
  value = "${module.travis_user.username}"
}
output "travis_access_key" {
  value = "${module.travis_user.access_key}"
}
output "travis_secret_access_key" {
  value = "${module.travis_user.encrypted_secret_access_key}"
}

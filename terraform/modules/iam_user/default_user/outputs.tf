# module outputs
# i.e. the attributes of the module component
output "username" {
  value = "${var.username}"
}

output "arn" {
  value = "${aws_iam_user.iam_user.arn}"
}

output "access_key" {
  value = "${aws_iam_access_key.iam_access_key.id}"
}

# TODO: if used without encryption (keybase pgp) poses a security risk
#       Provide pgp key and use 'encrypted_secret' instead
output "secret_access_key" {
  value = "${aws_iam_access_key.iam_access_key.secret}"
}

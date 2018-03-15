resource "aws_iam_user" "iam_user" {
    name = "${var.username}"
    path = "/"
}

resource "aws_iam_access_key" "iam_access_key" {
  user = "${aws_iam_user.iam_user.name}"
}

## TODO: for real users we may want to enable console login (PGP public key from keybase is required)
# resource "aws_iam_user_login_profile" "u" {
#   user    = "${aws_iam_user.iam_user.name}"
#   pgp_key = "keybase:some_person_that_exists"
# }

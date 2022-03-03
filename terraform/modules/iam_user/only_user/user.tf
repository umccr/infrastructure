resource "aws_iam_user" "iam_user" {
  name = var.username
  path = "/agha/"
  tags = {
    email   = var.email,
    name    = var.full_name,
    keybase = var.keybase
  }
}

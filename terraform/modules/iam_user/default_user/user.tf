resource "aws_iam_user" "iam_user" {
  name = var.username
  path = "/agha/"
  tags = {
    email   = var.email,
    name    = var.full_name,
    keybase = var.keybase
  }
}
resource "aws_iam_access_key" "iam_access_key" {
  user    = aws_iam_user.iam_user.name
  pgp_key = var.pgp_key
}
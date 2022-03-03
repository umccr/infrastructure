# module outputs
# i.e. the attributes of the module component
output "username" {
  value = var.username
}

output "arn" {
  value = aws_iam_user.iam_user.arn
}

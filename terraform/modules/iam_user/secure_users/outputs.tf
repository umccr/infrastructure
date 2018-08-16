# module outputs
# i.e. the attributes of the module component

output "access_keys" {
  value = "${zipmap(aws_iam_access_key.iam_access_key.*.user, aws_iam_access_key.iam_access_key.*.id)}"
}

output "encrypted_secret_access_keys" {
  value = "${zipmap(aws_iam_access_key.iam_access_key.*.user, aws_iam_access_key.iam_access_key.*.encrypted_secret)}"
}

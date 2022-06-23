### Service Users

# output for serivce: packer
#output "packer_username" {
#  value = "${module.packer_user.username}"
#}

#output "packer_access_key" {
#  value = "${module.packer_user.access_key}"
#}

#output "packer_secret_access_key" {
#  value = "${module.packer_user.encrypted_secret_access_key}"
#}

# output for serivce: terraform
output "terraform_username" {
  value = "${module.terraform_user.username}"
}

output "terraform_access_key" {
  value = "${module.terraform_user.access_key}"
}

output "terraform_secret_access_key" {
  value = "${module.terraform_user.encrypted_secret_access_key}"
}

# output for serivce: umccr_pipeline
output "umccr_pipeline_username" {
  value = "${module.umccr_pipeline_user.username}"
}

output "umccr_pipeline_access_key" {
  value = "${module.umccr_pipeline_user.access_key}"
}

output "umccr_pipeline_secret_access_key" {
  value = "${module.umccr_pipeline_user.encrypted_secret_access_key}"
}

# output for serivce: novastor_cloudwatch
output "novastor_cloudwatch_username" {
  value = "${module.novastor_cloudwatch_user.username}"
}

output "novastor_cloudwatch_access_key" {
  value = "${module.novastor_cloudwatch_user.access_key}"
}

output "novastor_cloudwatch_secret_access_key" {
  value = "${module.novastor_cloudwatch_user.encrypted_secret_access_key}"
}

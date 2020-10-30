################################################################################
# Stack
variable "stack_name" {
  default = "agha_infra"
}

########################################
# S3 buckets
variable "agha_gdr_staging_bucket_name" {
  default = "agha-gdr-staging"
}

variable "agha_gdr_store_bucket_name" {
  default = "agha-gdr-store"
}

########################################

variable "saml_provider" {
  default = "GoogleApps"
}

variable "slack_channel" {
  default = "#agha-gdr"
}

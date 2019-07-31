variable "stack_name" {
  default = "agha_gdr"
}

variable "saml_provider" {
  default = "GoogleApps"
}


################################################################################
# S3 buckets
variable "agha_gdr_staging_bucket_name" {
  default = "agha-gdr-staging"
}

variable "agha_gdr_store_bucket_name" {
  default = "agha-gdr-store"
}

variable "slack_channel" {
  default = "#agha-gdr"
}

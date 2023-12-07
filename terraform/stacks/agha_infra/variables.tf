################################################################################
# Stack
variable "stack_name" {
  default = "agha_infra"
}

########################################
# S3 buckets
variable "agha_gdr_archive_bucket_name" {
  default = "agha-gdr-archive"
}

variable "agha_gdr_staging_2_bucket_name" {
  default = "agha-gdr-staging-2.0"
}

variable "agha_gdr_results_2_bucket_name" {
  default = "agha-gdr-results-2.0"
}

variable "agha_gdr_store_2_bucket_name" {
  default = "agha-gdr-store-2.0"
}

########################################

variable "saml_provider" {
  default = "GoogleApps"
}

variable "slack_channel" {
  default = "#agha-gdr"
}

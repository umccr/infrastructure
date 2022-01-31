variable "stack_name" {
  default = "agha_users"
}

########################################
# S3 buckets
# (need to be the same as defined in the agha_infra stack)
variable "agha_gdr_staging_bucket_name" {
  default = "agha-gdr-staging-2.0"
}

variable "agha_gdr_store_bucket_name" {
  default = "agha-gdr-store-2.0"
}

variable "agha_gdr_mm_bucket_name" {
  default = "agha-gdr-mm"
}

variable "name" {
  description = "Base name for all resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ghcr_repo" {
  description = "GHCR image repo without tag ghcr.io/my-org/my-repo"
  type        = string
}

variable "ghcr_tag" {
  description = "Tag of GHRC image to use"
  type        = string
}

variable "cloudtrail_base_input_path" {
  description = "S3 URI of the CloudTrail bucket prefix, must end with / (this is the folder containing 'AWSLogs')"
  type        = string
}

variable "cloudtrail_base_output_path" {
  description = "S3 URI where Parquet output is written, must end with /"
  type        = string
}

variable "account_ids" {
  description = "AWS Account IDs"
  type        = list(string)
}

variable "organisation_id" {
  description = "AWS Organizations ID prefix, or null if none"
  type        = string
  default     = null
}


variable "process_date" {
  description = "Optional fixed date (YYYY-MM-DD) to pin as PROCESS_DATE. Leave empty for normal 'yesterday' behaviour."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 30
}

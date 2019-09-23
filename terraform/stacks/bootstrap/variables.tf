variable "stack_name" {
  default = "bootstrap"
}

variable "tf_bucket" {
  type = "string"
  default = "arn:aws:s3:::umccr-terraform-states"
}

################################################################################
## workspace variables

# due to a restriction in Terraform, we cannot dynamically define bucket configurations
# see: https://github.com/terraform-providers/terraform-provider-aws/issues/4418
# Therefore we need to manually configure each bucket and for that we need the individual names
variable "workspace_fastq_data_bucket_name" {
  default = {
    prod = "umccr-fastq-data-prod"
    dev  = "umccr-fastq-data-dev"
  }
}

variable "workspace_seq_data_bucket_name" {
  default = {
    prod = "umccr-raw-sequence-data-prod"
    dev  = "umccr-raw-sequence-data-dev"
  }
}

variable "workspace_fastq_data_uploader_buckets" {
  type = "map"

  default = {
    prod = ["arn:aws:s3:::umccr-fastq-data-prod", "arn:aws:s3:::umccr-fastq-data-prod/*", "arn:aws:s3:::umccr-primary-data-prod", "arn:aws:s3:::umccr-primary-data-prod/*", "arn:aws:s3:::umccr-raw-sequence-data-prod", "arn:aws:s3:::umccr-raw-sequence-data-prod/*", "arn:aws:s3:::umccr-umccrise-refdata-prod", "arn:aws:s3:::umccr-umccrise-refdata-prod/*", "arn:aws:s3:::umccr-temp", "arn:aws:s3:::umccr-temp/*"]
    dev  = ["arn:aws:s3:::umccr-fastq-data-dev", "arn:aws:s3:::umccr-fastq-data-dev/*", "arn:aws:s3:::umccr-primary-data-dev", "arn:aws:s3:::umccr-primary-data-dev/*", "arn:aws:s3:::umccr-raw-sequence-data-dev", "arn:aws:s3:::umccr-raw-sequence-data-dev/*", "arn:aws:s3:::umccr-umccrise-refdata-dev", "arn:aws:s3:::umccr-umccrise-refdata-dev/*"]
  }
}

variable "workspace_operator_write_buckets" {
  type = "map"

  default = {
    prod = ["arn:aws:s3:::umccr-fastq-data-prod", "arn:aws:s3:::umccr-fastq-data-prod/*",
            "arn:aws:s3:::umccr-raw-sequence-data-prod", "arn:aws:s3:::umccr-raw-sequence-data-prod/*",
            "arn:aws:s3:::umccr-primary-data-prod", "arn:aws:s3:::umccr-primary-data-prod/*",
            "arn:aws:s3:::umccr-umccrise-refdata-prod", "arn:aws:s3:::umccr-umccrise-refdata-prod/*",
            "arn:aws:s3:::umccr-temp", "arn:aws:s3:::umccr-temp/*"]
    dev  = ["arn:aws:s3:::umccr-fastq-data-dev", "arn:aws:s3:::umccr-fastq-data-dev/*",
            "arn:aws:s3:::umccr-raw-sequence-data-dev", "arn:aws:s3:::umccr-raw-sequence-data-dev/*",
            "arn:aws:s3:::umccr-primary-data-dev", "arn:aws:s3:::umccr-primary-data-dev/*",
            "arn:aws:s3:::umccr-umccrise-refdata-dev", "arn:aws:s3:::umccr-umccrise-refdata-dev/*"]
  }
}

variable "workspace_pcgr_bucket_name" {
  default = {
    prod = "umccr-pcgr-prod"
    dev  = "umccr-pcgr-dev"
  }
}

variable "workspace_primary_data_bucket_name" {
  default = {
    prod = "umccr-primary-data-prod"
    dev  = "umccr-primary-data-dev"
  }
}

variable "workspace_vault_bucket_name" {
  default = {
    prod = "umccr-vault-data-prod"
    dev  = "umccr-vault-data-dev"
  }
}

variable "workspace_root_domain" {
  default = {
    prod = "prod.umccr.org"
    dev  = "dev.umccr.org"
  }
}

variable "workspace_vault_env" {
  default = {
    prod = "PROD"
    dev  = "DEV"
  }
}

variable "workspace_vault_instance_tags" {
  default = {
    prod = "[{\"Key\": \"Name\", \"Value\": \"vault_prod\"},{\"Key\": \"Stack\", \"Value\": \"bootstrap\"},{\"Key\": \"Environment\", \"Value\": \"prod\"}]"
    dev  = "[{\"Key\": \"Name\", \"Value\": \"vault_dev\"},{\"Key\": \"Stack\", \"Value\": \"bootstrap\"},{\"Key\": \"Environment\", \"Value\": \"dev\"}]"
  }
}

variable "workspace_slack_channel" {
  default = {
    prod = "#biobots"
    dev  = "#arteria-dev"
  }
}

variable "workspace_pipeline_activity_name" {
  default = {
    prod = "umccr_pipeline_wait_for_async_action_prod"
    dev  = "umccr_pipeline_wait_for_async_action_dev"
  }
}

variable "workspace_slack_lambda_name" {
  default = {
    prod = "bootstrap_slack_lambda_prod"
    dev  = "bootstrap_slack_lambda_dev"
  }
}

variable "workspace_submission_lambda_name" {
  default = {
    prod = "umccr_pipeline_job_submission_lambda_prod"
    dev  = "umccr_pipeline_job_submission_lambda_dev"
  }
}

variable "workspace_state_machine_name" {
  default = {
    prod = "umccr_pipeline_state_machine_prod"
    dev  = "umccr_pipeline_state_machine_dev"
  }
}

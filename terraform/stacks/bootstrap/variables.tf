variable "stack_name" {
  default = "bootstrap"
}

variable "vault_instance_type" {
  default = "t2.micro"
}

variable "vault_instance_spot_price" {
  default = "0.0045"
}

variable "vault_availability_zone" {
  default = "ap-southeast-2a"
}

variable "vault_sub_domain" {
  default = "vault"
}

################################################################################
## workspace variables

variable "workspace_name_suffix" {
  default = {
    prod = "_prod"
    dev  = "_dev"
  }
}

variable "workspace_deploy_env" {
  default = {
    prod = "prod"
    dev  = "dev"
  }
}

# due to a restriction in Terraform, we cannot dynamically define bucket configurations
# see: https://github.com/terraform-providers/terraform-provider-aws/issues/4418
# Therefore we need to manually configure each bucket and for that we need the individual names
variable "workspace_fastq_data_bucket_name" {
  default = {
    prod = "umccr-fastq-data-prod"
    dev  = "umccr-fastq-data-dev"
  }
}

variable "workspace_fastq_data_uploader_buckets" {
  type = "map"

  default = {
    prod = ["arn:aws:s3:::umccr-fastq-data-prod", "arn:aws:s3:::umccr-fastq-data-prod/*", "arn:aws:s3:::umccr-primary-data-prod", "arn:aws:s3:::umccr-primary-data-prod/*"]
    dev  = ["arn:aws:s3:::umccr-fastq-data-dev", "arn:aws:s3:::umccr-fastq-data-dev/*", "arn:aws:s3:::umccr-primary-data-dev", "arn:aws:s3:::umccr-primary-data-dev/*"]
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

variable "workspace_enable_bucket_lifecycle_rule" {
  default = {
    prod = true
    dev  = false
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

variable "workspace_state_machine_name" {
  default = {
    prod = "umccr_pipeline_state_machine_prod"
    dev  = "umccr_pipeline_state_machine_dev"
  }
}

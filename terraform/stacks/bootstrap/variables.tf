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

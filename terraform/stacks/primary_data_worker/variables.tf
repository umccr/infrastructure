################################################################################
# General variables

variable "stack_name" {
  default = "primary_data_worker"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "instance_vol_size" {
  default = 10
}

variable "instance_profile_name" {
  default = "ssm_manual_instance_role"
}

################################################################################
# Workspace specific variables

variable "workspace_buckets" {
  type = "map"

  default = {
    dev = ["umccr-primary-data-dev"]
    prod = ["umccr-primary-data-prod"]
  }
}

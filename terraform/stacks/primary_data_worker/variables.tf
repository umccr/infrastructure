################################################################################
# General variables

variable "stack_name" {
  default = "primary_data_worker"
}

variable "instance_ami" {
  default = "ami-02fd0b06f06d93dfc"
}

variable "instance_type" {
  default = "m4.large"
}

variable "instance_vol_size" {
  default = 300
}

variable "instance_profile_name" {
  default = "AmazonEC2InstanceProfileforSSM"
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

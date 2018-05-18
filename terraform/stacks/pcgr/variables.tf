variable "stack" {
  description = "Name of the Stack."
  default     = "pcgr"
}

variable "instance_type" {
  description = "The EC2 instance type to use for the pcgr instance."
  default     = "m4.xlarge"
}

variable "instance_spot_price" {
  description = "The spot price limit for the EC2 instance."
  default     = "0.09"
}

variable "availability_zone" {
  description = "The availability_zone in which to create the resources."
  default     = "ap-southeast-2a"
}

################################################################################
## workspace variables

variable "workspace_name_suffix" {
  description = "Suffix to be applied to AWS resource names in order to make them unique. This way the module can be deployed several times into the same account without causing name clashes."
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

variable "workspace_st2_host" {
  description = "The host of where StackStorm is running."
  default = {
    prod = "stackstorm.prod.umccr.org"
    dev  = "stackstorm.dev.umccr.org"
  }
}

################################################################################
## workspace variables

variable "workspace_name_suffix" {
  default = {
    prod = "_prod"
    dev  = "_dev"
  }
}

variable "availability_zone" {
  default = "ap-southeast-2a"
}

variable "umccrise_image_id" {
  default = "ami-024c4797eeeb81876"
}

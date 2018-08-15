################################################################################
## workspace variables

variable "workspace_name_suffix" {
  default = {
    prod = "_prod"
    dev  = "_dev"
  }
}

variable "availability_zone" {
  default = "ap-southeast-2c"
}

variable "umccrise_image_id" {
  default = "ami-038937e6db20b624f"
}

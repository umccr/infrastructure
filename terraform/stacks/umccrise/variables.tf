################################################################################
## workspace variables

variable "workspace_name_suffix" {
  default = {
    prod = "_prod"
    dev  = "_dev"
  }
}

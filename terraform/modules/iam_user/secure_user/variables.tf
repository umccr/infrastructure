# module inputs
# i.e. the arguments to the module component
variable "username" {
  type = "string"
}

variable "pgp_key" {
  type = "string"
}

variable "email" {
  type = "string"
  default = "none"
}

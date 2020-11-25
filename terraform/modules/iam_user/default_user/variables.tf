# module inputs
variable "username" {
  type = string
}

variable "pgp_key" {
  type    = string
}

# variables to tags
variable "keybase" {
  type    = string
  default = null
}

variable "full_name" {
  type    = string
  default = null
}

variable "email" {
  type    = string
  default = null
}

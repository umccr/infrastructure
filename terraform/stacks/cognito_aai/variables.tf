variable "base_domain" {
  default = {
    prod = "prod.umccr.org"
    dev  = "dev.umccr.org"
  }
  description = "Base domain for current stage"
}

variable "localhost_url" {
  default     = "http://localhost:3000"
  description = "The localhost url used for testing"
}

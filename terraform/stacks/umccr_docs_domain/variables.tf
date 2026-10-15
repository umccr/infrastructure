variable "base_domain" {
  default = {
    prod = "prod.umccr.org"
    dev  = "dev.umccr.org"
    stg  = "stg.umccr.org"
  }
  description = "Base domain for current stage"
}

variable "alias_domain" {
  default = {
    prod = "docs.umccr.org"
    dev  = ""
    stg  = ""
  }
  description = "Additional docs hostname served by the stage's distribution, if any"
}

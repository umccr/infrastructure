# docs.umccr.org runs in dev and prod only, so these are the only workspaces.
variable "base_domain" {
  default = {
    prod = "prod.umccr.org"
    dev  = "dev.umccr.org"
  }
  description = "Base domain for current stage"
}

variable "alias_domain" {
  default = {
    prod = "docs.umccr.org"
    dev  = ""
  }
  description = "Additional docs hostname served by the stage's distribution, if any"
}

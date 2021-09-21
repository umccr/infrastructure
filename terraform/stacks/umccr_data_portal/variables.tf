variable "base_domain" {
  default = {
    prod = "prod.umccr.org"
    dev  = "dev.umccr.org"
  }
  description = "Base domain for current stage"
}

variable "alias_domain" {
  default = {
    prod = "data.umccr.org"
    dev  = ""
  }
  description = "Additional domains to alias base_domain"
}

# NOTE:
# Automatic cert validation required to create records in hosted zone (zone_id), see [1].
# Since subject alternate name compose of alias_domain -- data.umccr.org, which is hosted in BASTION account (i.e required cross-account access).
# So, from PROD account, it is not able to automatically create DNS validation record set in BASTION Route53 resource.
# Therefore, cert will be just created and pending DNS validation.
# And requires manually add DNS records for validation, this can be done through ACM Console UI to respective account Route53 zones.
# Need to be done only once upon a fresh initial deployment.
# [1]: https://www.terraform.io/docs/providers/aws/r/acm_certificate_validation.html#alternative-domains-dns-validation-with-route-53
variable "certificate_validation" {
  default = {
    prod = 0
    dev  = 1
  }
  description = "Whether automatic validate the cert (1) or, to manually validate (0)"
}

variable "github_branch" {
  default = {
    prod = "main"
    dev  = "dev"
  }
  description = "The branch corresponding to current stage"
}

variable "localhost_url" {
  default     = "http://localhost:3000"
  description = "The localhost url used for testing"
}

variable "rds_auto_pause" {
  default = {
    prod = false
    dev  = false
  }
  description = "Whether to keep RDS serverless alive or pause if no load"
}

variable "rds_min_capacity" {
  default = {
    prod = 1
    dev  = 1
  }
  description = "The minimum capacity in Aurora Capacity Units (ACUs)"
}

variable "rds_max_capacity" {
  default = {
    prod = 16
    dev  = 16
  }
  description = "The maximum capacity in Aurora Capacity Units (ACUs)"
}

variable "rds_backup_retention_period" {
  default = {
    prod = 7
    dev  = 1
  }
  description = "RDS Aurora managed automated backup, must have 1 at least for Aurora Serverless DB"
}

variable "create_aws_backup" {
  default = {
    prod = 1
    dev  = 0
  }
  description = "Create AWS Backup for RDS Aurora Serverless DB, 1 create, 0 not"
}

variable "slack_channel" {
  default = {
    prod = "#biobots",
    dev  = "#arteria-dev"
  }
  description = "Slack channel to send operational status message"
}

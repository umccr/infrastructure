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
    prod = "data.umccr.org"
    dev  = ""
    stg  = ""
  }
  description = "Additional domains to alias base_domain"
}

# FIXME: https://github.com/umccr/infrastructure/issues/272
variable "alias_domain2" {
  default = {
    prod = "portal.umccr.org"
    dev  = ""
    stg  = ""
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
    stg  = 1
  }
  description = "Whether automatic validate the cert (1) or, to manually validate (0)"
}

variable "github_branch_backend" {
  default = {
    prod = "main"
    dev  = "dev"
    stg  = "stg"
  }
  description = "The branch corresponding to current stage"
}

variable "github_branch_frontend" {
  default = {
    prod = "v1-main"
    dev  = "dev"
    stg  = "stg"
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
    stg  = false
  }
  description = "Whether to keep RDS serverless alive or pause if no load"
}

variable "rds_min_capacity" {
  default = {
    prod = 0.5
    dev  = 0.5
    stg  = 0.5
  }
  description = "The minimum capacity in Aurora Capacity Units (ACUs)"
}

variable "rds_max_capacity" {
  default = {
    prod = 16.0
    dev  = 4.0
    stg  = 16.0
  }
  description = "The maximum capacity in Aurora Capacity Units (ACUs)"
}

variable "rds_backup_retention_period" {
  default = {
    prod = 7
    dev  = 1
    stg  = 7
  }
  description = "RDS Aurora managed automated backup, must have 1 at least for Aurora Serverless DB"
}

variable "create_aws_backup" {
  default = {
    prod = 1
    dev  = 0
    stg  = 1
  }
  description = "Create AWS Backup for RDS Aurora Serverless DB, 1 create, 0 not"
}

variable "slack_channel" {
  default = {
    prod = "#biobots",
    dev  = "#arteria-dev"
    stg  = "#devops-alerts"
  }
  description = "Slack channel to send operational status message"
}

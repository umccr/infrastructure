
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
# Automatic cert validation required to create records in hosted zone (zone_id), see [1]
# Since subject alternate name compose of alias_domain, which is hosted in bastion account
# so, it is not able to automatically create DNS validation record set this way
# Therefore, cert will be just created and pending DNS validation
# And requires manually add DNS records for validation, this can be done through ACM Console UI to respective Route53 zones
# Need to be done once upon a fresh initial deployment
# [1]: https://www.terraform.io/docs/providers/aws/r/acm_certificate_validation.html#alternative-domains-dns-validation-with-route-53
variable "certificate_validation" {
    default = {
        prod = 0
        dev  = 1
    }
    description = "Whether automatic validate the cert (1) or, to manually validate (0)"
}

variable "lims_bucket" {
    default = {
        prod = "umccr-data-google-lims-prod" 
        dev = "umccr-data-google-lims-dev" 
    }
    description = "Name of the S3 bucket storing lims data to be used by crawler "
}

variable "s3_primary_data_bucket" {
    default = {
        prod = "umccr-primary-data-prod"
        dev  = "umccr-primary-data-dev"
    }
    description = "Name of the S3 bucket storing s3 primary data to be used by crawler "
}

variable "s3_run_data_bucket" {
    default = {
        prod = "umccr-run-data-prod"
        dev  = "umccr-run-data-dev"
    }
    description = "Name of the S3 bucket storing s3 run data to be used by crawler "
}

variable "github_branch" {
    default = {
        prod = "master"
        dev  = "dev"
    }
    description = "The branch corresponding to current stage"
}

variable "localhost_url" {
    default     = "http://localhost:3000",
    description = "The localhost url used for testing"
}

variable "lims_csv_file_key" {
    default = "google_lims.csv"
    description = "CSV File key"
}

variable "rds_auto_pause" {
    default = {
        prod = true,
        dev = false
    }
    description = "Whether we always keep serverless rds alive"
}

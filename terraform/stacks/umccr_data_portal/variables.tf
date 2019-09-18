variable "org_domain" {
    default = {
        prod = "prod.umccr.org"
        dev  = "dev.umccr.org"
    }
    description = "Organisation domain for current stage"
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
    description = "Name of the S3 bucket storing s3 keys data to be used by crawler "
}

# Terraform doesn't currently support configuraing google oauth credentials
# https://github.com/terraform-providers/terraform-provider-google/issues/1287
variable "google_app_id" {
    default = {
        prod = "1077202000373-d21cktrmves8u9e0mpmuosfld2gngv2s.apps.googleusercontent.com"
        dev = "1077202000373-61vctlp83rjrr4i2aab89ms5fagbakdp.apps.googleusercontent.com"
    }
    description = "Client ID of Google OAuth 2.0"
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
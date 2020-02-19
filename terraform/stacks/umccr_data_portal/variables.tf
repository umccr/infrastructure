
variable "base_domain" {
    default = {
        prod = "prod.umccr.org"
        dev  = "dev.umccr.org"
    }
    description = "Base domain for current stage"
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

variable "org_domain" {
    default = {
        prod = "prod.umccr.org"
        dev  = "dev.umccr.org"
    }
}

variable "lims_bucket_for_crawler" {
    default = {
        prod = ""
        dev = ""
    }
}

variable "s3_keys_bucket_for_crawler" {
    default = {
        prod = ""
        dev  = ""
    }
}

variable "google_app_id" {
    default = {
        prod = ""
        dev = "1077202000373-61vctlp83rjrr4i2aab89ms5fagbakdp.apps.googleusercontent.com"
    }
}

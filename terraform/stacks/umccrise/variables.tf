variable "availability_zone" {
  default = "ap-southeast-2c"
}

variable "stack_name" {
  default = "umccrise"
}

variable "umccrise_refdata_bucket" {
  default = "umccr-refdata-prod"
}

variable "job_definition_name" {
  description ="The JobDefinition name the stack is allowed to register"
  default = "umccrise"
}


################################################################################
## workspace variables

variable "workspace_umccrise_image_id" {
  type = "map"

  default = {
    prod = "ami-09975fb45a9e256c3"
    dev  = "ami-0e3451906ffc529a0"
  }
}


variable "workspace_slack_lambda_arn" {
  type = "map"

  default = {
    prod = "arn:aws:lambda:ap-southeast-2:472057503814:function:bootstrap_slack_lambda_prod"
    dev  = "arn:aws:lambda:ap-southeast-2:620123204273:function:bootstrap_slack_lambda_dev"
  }
}

variable "workspace_umccrise_data_bucket" {
  type = "map"

  default = {
    prod = "umccr-primary-data-prod"
    dev  = "umccr-primary-data-dev2"
  }
}

variable "workspace_umccrise_temp_bucket" {
  type = "map"

  default = {
    prod = "umccr-temp"
    dev  = "umccr-umccrise-dev"
  }
}

variable "workspace_umccrise_ro_buckets" {
  type = "map"

  default = {
    prod = ["arn:aws:s3:::umccr-primary-data-prod", "arn:aws:s3:::umccr-primary-data-prod/*",
            "arn:aws:s3:::umccr-validation-prod", "arn:aws:s3:::umccr-validation-prod/*",
            "arn:aws:s3:::umccr-refdata-prod", "arn:aws:s3:::umccr-refdata-prod/*"]
    dev  = ["arn:aws:s3:::umccr-primary-data-prod", "arn:aws:s3:::umccr-primary-data-prod/*",
            "arn:aws:s3:::umccr-validation-prod", "arn:aws:s3:::umccr-validation-prod/*",
            "arn:aws:s3:::umccr-refdata-prod", "arn:aws:s3:::umccr-refdata-prod/*",
            "arn:aws:s3:::umccr-primary-data-dev", "arn:aws:s3:::umccr-primary-data-dev/*",
            "arn:aws:s3:::umccr-primary-data-dev2", "arn:aws:s3:::umccr-primary-data-dev2/*",
            "arn:aws:s3:::umccr-refdata-dev", "arn:aws:s3:::umccr-refdata-dev/*",
            "arn:aws:s3:::umccr-research-dev", "arn:aws:s3:::umccr-research-dev/*",
            "arn:aws:s3:::umccr-temp-dev", "arn:aws:s3:::umccr-temp-dev/*"]
  }
}

variable "workspace_umccrise_wd_buckets" {
  type = "map"

  default = {
    prod = ["arn:aws:s3:::umccr-primary-data-prod/*/umccrised/*",
            "arn:aws:s3:::umccr-validation-prod/*/umccrised/*"]
    dev  = ["arn:aws:s3:::umccr-primary-data-dev2/*/umccrised/*",
            "arn:aws:s3:::umccr-primary-data-dev/*/umccrised/*",
            "arn:aws:s3:::umccr-research-dev/*/umccrised/*",
            "arn:aws:s3:::umccr-temp-dev/*/umccrised/*"]
  }
}

variable "umccrise_mem" {
  type = "map"

  default = {
    prod = 50000
    dev = 50000
  }
}
variable "umccrise_vcpus" {
  type = "map"

  default = {
    prod = 16
    dev = 16
  }
}

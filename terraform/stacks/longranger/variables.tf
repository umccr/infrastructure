################################################################################
## workspace variables

variable "availability_zone" {
  default = "ap-southeast-2c"
}

variable "longranger_image_id" {
  default = "ami-03037fc9d9ca37131"
}

variable "stack_name" {
  default = "longranger"
}

variable "workspace_longranger_data_bucket" {
  type    = "map"
  default = {
    prod = "umccr-primary-data-prod"
    dev  = "umccr-primary-data-dev"
  }
}

variable "workspace_longranger_buckets" {
  type = "map"

  default = {
    prod = ["arn:aws:s3:::umccr-primary-data-prod", "arn:aws:s3:::umccr-primary-data-prod/*", "arn:aws:s3:::umccr-umccrise-refdata-prod", "arn:aws:s3:::umccr-umccrise-refdata-prod/*"]
    dev  = ["arn:aws:s3:::umccr-primary-data-dev", "arn:aws:s3:::umccr-primary-data-dev/*", "arn:aws:s3:::umccr-umccrise-refdata-dev", "arn:aws:s3:::umccr-umccrise-refdata-dev/*"]
  }
}

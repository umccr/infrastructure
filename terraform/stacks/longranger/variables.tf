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
    prod = "umccr-longranger-prod"
    dev  = "umccr-longranger-dev"
  }
}

variable "workspace_longranger_buckets" {
  type = "map"

  default = {
    prod = ["arn:aws:s3:::umccr-longranger-prod", "arn:aws:s3:::umccr-longranger-prod/*", "arn:aws:s3:::umccr-longranger-refdata-prod", "arn:aws:s3:::umccr-longranger-refdata-prod/*"]
    dev  = ["arn:aws:s3:::umccr-longranger-dev", "arn:aws:s3:::umccr-longranger-dev/*", "arn:aws:s3:::umccr-longranger-refdata-dev", "arn:aws:s3:::umccr-longranger-refdata-dev/*"]
  }
}

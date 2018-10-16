variable "aws_region" {
  type    = "string"
  default = "ap-southeast-2"
}

variable "availability_zone" {
  type    = "string"
  default = "ap-southeast-2a"
}

variable "stack_name" {
  default = "agha_incoming"
}

variable "instance_type" {
  type    = "string"
  default = "t3.micro"
}

variable "instance_ami" {
  type    = "string"
  default = "ami-6bc21b09"
}

variable "instance_spot_price" {
  type    = "string"
  default = "0.02"
}

# workspace specific variables

variable "workspace_instance_tags" {
  type        = "map"
  description = "Tags in json format, see https://docs.aws.amazon.com/cli/latest/reference/ec2/create-tags.html"

  default = {
    dev = "[{\"Key\": \"Name\", \"Value\": \"agha_incoming_dev\"},{\"Key\": \"Stack\", \"Value\": \"agha_incoming\"},{\"Key\": \"Environment\", \"Value\": \"dev\"}]"
  }
}

variable "workspace_agha_buckets" {
  type = "map"

  default = {
    dev = ["arn:aws:s3:::agha-gdr-staging-dev", "arn:aws:s3:::uagha-gdr-staging-dev/*", "arn:aws:s3:::agha-gdr-log-dev", "arn:aws:s3:::agha-gdr-log-dev/*", "arn:aws:s3:::agha-gdr-store-dev", "arn:aws:s3:::agha-gdr-store-dev/*"]
  }
}

variable "workspace_agha_staging_bucket" {
  type = "map"

  default = {
    dev = "agha-gdr-staging-dev"
  }
}

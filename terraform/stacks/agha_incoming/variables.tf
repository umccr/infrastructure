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
  default = "m5a.xlarge"
}

# workspace specific variables

variable "instance_tags" {
  description = "Tags in json format, see https://docs.aws.amazon.com/cli/latest/reference/ec2/create-tags.html"

  default = "[{\"Key\": \"Name\", \"Value\": \"agha_incoming_dev\"},{\"Key\": \"Stack\", \"Value\": \"agha_incoming\"},{\"Key\": \"Environment\", \"Value\": \"agha\"}]"
}

variable "agha_buckets" {
  type = "list"

  default = ["agha-gdr-staging", "agha-gdr-store"]
}

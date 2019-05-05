variable "aws_region" {
  type    = "string"
  default = "ap-southeast-2"
}

variable "availability_zone" {
  type    = "string"
  default = "ap-southeast-2a"
}

variable "stack_name" {
  default = "ec2_instance"
}

variable "instance_type" {
  type    = "string"
  default = "t2.micro"
}

variable "instance_ami" {
  type    = "string"
  default = "ami-04481c741a0311bbb"  # AWS Linux 2
}

variable "instance_spot_price" {
  type    = "string"
  default = "0.02"
}

# workspace specific variables

variable "instance_tags" {
  description = "Tags in json format, see https://docs.aws.amazon.com/cli/latest/reference/ec2/create-tags.html"

  default = "[{\"Key\": \"Name\", \"Value\": \"aws_onboarding\"},{\"Key\": \"Stack\", \"Value\": \"ec2_instance\"},{\"Key\": \"Environment\", \"Value\": \"ec2\"}]"
}

variable "onboarding_bucket" {
  type = "list"

  default = ["umccr-onboarding-test"]
}

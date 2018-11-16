variable "stack_name" {
  type    = "string"
  default = "basespace_playground"
}

variable "deploy_env" {
  type        = "string"
  description = "The deployment environment against which to deploy this stack. Select either 'dev' or 'prod'."
  default     = "dev"
}

variable "aws_region" {
  type    = "string"
  default = "ap-southeast-2"
}

variable "availability_zone" {
  type    = "string"
  default = "ap-southeast-2a"
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

variable "eip_name_tag" {
  type        = "string"
  description = "The Name tag by which to find an Elastic IP to assign to the instance."
  default     = "basespace_playground_dev"
}

variable "instance_tags" {
  type        = "string"
  description = "Tags in json format, see https://docs.aws.amazon.com/cli/latest/reference/ec2/create-tags.html"
  default     = "[{\"Key\": \"Name\", \"Value\": \"basespace_playground_dev\"},{\"Key\": \"Stack\", \"Value\": \"basespace_playground\"},{\"Key\": \"Environment\", \"Value\": \"dev\"}]"
}

variable "buckets" {
  type        = "list"
  description = "The S3 buckets to mount to"
  default     = ["umccr-primary-data-dev"]
}

variable "stack" {
  description = "Name of the Stack."
  default     = "pcgr"
}

variable "instance_type" {
  description = "The EC2 instance type to use for the stackstorm instance."
  default     = "m4.xlarge"
}

variable "ami_filters" {
  description = "The filters to use when looking for the AMI to use."

  default = [
    {
      name   = "tag:ami"
      values = ["pcgr-ami"]
    },
  ]
}

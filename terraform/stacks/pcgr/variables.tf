variable "stack" {
  description = "Name of the Stack."
  default     = "pcgr"
}

variable "instance_type" {
  description = "The EC2 instance type to use for the stackstorm instance."
  default     = "m4.xlarge"
}

variable "name_suffix" {
  description = "Suffix to be applied to AWS resource names in order to make them unique. This way the module can be deployed several times into the same account without causing name clashes."
  default     = "_prod"
}

variable "availability_zone" {
  description = "The availability_zone in which to create the resources."
  default     = "ap-southeast-2"
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

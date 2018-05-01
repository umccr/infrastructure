variable "name_suffix" {
  description = "Suffix to be applied to AWS resource names in order to make them unique. This way the module can be deployed several times into the same account without causing name clashes."
}

variable "instance_type" {
  description = "The EC2 instance type to use for the stackstorm instance."
}

variable "availability_zone" {
  description = "The availability_zone in which to create the resources."
}

variable "root_domain" {
  description = "The root domain to base the AWS route53 zone and subsequent records on, e.g. 'prod.umccr.org'."
}

variable "YOUR_MODULE_sub_domain" {
  description = "The sub domain to for YOUR_STACK service: YOUR_STACK.prod.umccr.org."
}

variable "ami_filters" {
  description = "The filters to use when looking for the AMI to use."

  default = [
    {
      name   = "tag:ami"
      values = ["YOUR_MODULE-ami"]
    },
  ]
}

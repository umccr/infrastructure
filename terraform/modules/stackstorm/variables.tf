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

variable "stackstorm_sub_domain" {
  description = "The sub domain to for the StackStorm service, e.g. 'stackstorm'. Used in conjunction with the root_domain to produce 'stackstorm.prod.umccr.org'."
}

variable "stackstorm_data_volume_name" {
  description = "The name (i.e. value of tag 'Name') of the EBS volume that contains the stackstorm configuration data."
}

variable "stackstorm_docker_volume_name" {
  description = "The name (i.e. value of tag 'Name') of the EBS volume that is used to hold docker volume data."
}

variable "st2_hostname" {
  description = "The hostname of the stackstorm instance DataDog will be using to collect the metrics/logs."
}

variable "ami_filters" {
  description = "The filters to use when looking for the AMI to use."
  default = [
    {
      name   = "tag:ami"
      values = ["stackstorm-ami"]
    }
  ]
}

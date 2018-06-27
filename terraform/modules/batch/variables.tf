variable "availability_zone" {
  description = "The availability zone to deploy to."
}

variable "name_suffix" {
  description = "Suffix to be applied to AWS resource names in order to make them unique. This way the module can be deployed several times into the same account without causing name clashes."
}

variable "compute_env_name" {
  description = "The name to give to the compute environment."
}

variable "image_id" {
  description = "The AMI to use for the compute resource EC2 machines."
}

variable "instance_types" {
  type        = "list"
  description = "An array with the instance types to use for the compute resource."
}

variable "security_group_ids" {
  type        = "list"
  description = "An array with the security group IDs to use for the compute resource."
}

variable "subnet_ids" {
  type        = "list"
  description = "An array with the subnet IDs to use for the compute resource."
}

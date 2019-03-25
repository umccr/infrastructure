variable "availability_zone" {
  description = "The availability zone to deploy to."
}

variable "name_suffix" {
  description = "Suffix to be applied to AWS resource names in order to make them unique. This way the module can be deployed several times into the same account without causing name clashes."
}

variable "stack_name" {
  description = "Name of the stack, which can be applied to AWS resource names in order to make them unique and easisy identifiable."
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

variable "ec2_additional_policy" {
  type        = "string"
  description = "Additional policies the EC2 instances of the batch compute env should carry. In addtision to the default AmazonEC2ContainerServiceforEC2Role"
}


# Definitions for the parameters below on: https://docs.aws.amazon.com/batch/latest/userguide/Batch_GetStarted.html
variable "max_vcpus" {
  type        = "string"
  description = "For Maximum vCPUs, choose the maximum number of EC2 vCPUs that your compute environment can scale out to, regardless of job queue demand."
  default     = 32
}

variable "min_vcpus" {
  type        = "string"
  description = "For Minimum vCPUs, choose the minimum number of EC2 vCPUs that your compute environment should maintain, regardless of job queue demand."
  default     = 0
}

variable "spot_bid_percent" {
  type        = "string"
  description = "The percent to bid for on a SPOT fleet"
  default     = 50
}

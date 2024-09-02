variable "umccr_subnet_tier" {
  # Follow UMCCR specific tag convention
  # https://github.com/umccr/wiki/tree/master/computing/cloud/amazon#general-conventions
  default = {
    PRIVATE  = "private"
    PUBLIC   = "public"
    DATABASE = "database"
  }
}

variable "aws_cdk_subnet_type" {
  # Follow CDK convention
  # https://github.com/aws/aws-cdk/blob/v1.44.0/packages/@aws-cdk/aws-ec2/lib/vpc.ts#L139
  default = {
    PRIVATE  = "Private"
    PUBLIC   = "Public"
    ISOLATED = "Isolated"
  }
}

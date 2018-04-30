variable "ami_filters" {
  description = "The filters to use when looking for the AMI to use."
  # default = [
  #   {
  #     name   = "tag:ami"
  #     values = ["stackstorm-ami"]
  #   }
  # ]
  default = [
    {
      name  = "image-id"
      values = ["ami-f8ae639a"]
    }
  ]
}

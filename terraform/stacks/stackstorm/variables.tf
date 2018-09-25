variable "stack_name" {
  default = "stackstorm"
}


# TODO: use 'locals': https://medium.com/@diogok/terraform-workspaces-and-locals-for-environment-separation-a5b88dd516f5
variable "workspace_name_suffix" {
  default = {
    prod = "_prod"
    dev  = "_dev"
  }
}
variable "workspace_zone_domain" {
  default = {
    prod = "prod.umccr.org"
    dev  = "dev.umccr.org"
  }
}
# NOTE: the volumes could have the same name as long as they are in different AWS accounts, keeping them different however allows the deployment of the stack into the same account
variable "workspace_st_data_volume" {
  default = {
    prod = "stackstorm-data-prod"
    dev  = "stackstorm-data-dev"
  }
}
variable "workspace_st_docker_volume" {
  default = {
    prod = "stackstorm-docker-volumes-prod"
    dev  = "stackstorm-docker-volumes-dev"
  }
}
variable "workspace_dd_hostname" {
  default = {
    prod = "umccr-stackstorm-prod"
    dev  = "" # NOTE: if empty then no datadog container will be launched (avoiding additional DataDog charges)
  }
}


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

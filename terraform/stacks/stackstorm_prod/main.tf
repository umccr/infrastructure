terraform {
  backend "s3" {
    bucket  = "umccr-terraform-states"
    key     = "stackstorm/terraform.tfstate"
    region  = "ap-southeast-2"
    profile = "umccr_bastion"
  }
}

# TODO: use 'locals': https://medium.com/@diogok/terraform-workspaces-and-locals-for-environment-separation-a5b88dd516f5
variable "workspace_name_suffix" {
  default = {
    prod = "_prod"
    play = "_play"
  }
}
variable "workspace_zone_domain" {
  default = {
    prod = "prod.umccr.org"
    play = "play.umccr.org"
  }
}
variable "workspace_st_data_volume" {
  default = {
    prod = "stackstorm-data-prod"
    play = "stackstorm-data-play"
  }
}
variable "workspace_st_docker_volume" {
  default = {
    prod = "stackstorm-docker-volumes-prod"
    play = "stackstorm-docker-volumes-play"
  }
}
variable "workspace_dd_hostname" {
  default = {
    prod = "umccr-stackstorm-prod"
    play = ""
  }
}

provider "aws" {
  region      = "ap-southeast-2"
}


module "stackstorm" {
  source                        = "../../modules/stackstorm"
  instance_type                 = "t2.medium"
  name_suffix                   = "${var.workspace_name_suffix[terraform.workspace]}"
  availability_zone             = "ap-southeast-2a"
  root_domain                   = "${var.workspace_zone_domain[terraform.workspace]}"
  stackstorm_sub_domain         = "stackstorm"
  stackstorm_data_volume_name   = "${var.workspace_st_data_volume[terraform.workspace]}" # NOTE: volume must exist
  stackstorm_docker_volume_name = "${var.workspace_st_docker_volume[terraform.workspace]}" # NOTE: volume must exist
  st2_hostname                  = "${var.workspace_dd_hostname[terraform.workspace]}"
  # ami_filters                   = "${var.ami_filters}" # can be used to overwrite the default AMI lookup
}

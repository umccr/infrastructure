terraform {
  backend "s3" {
    bucket  = "umccr-terraform-prod"
    key     = "stackstorm-prod/terraform.tfstate"
    region  = "ap-southeast-2"
  }
}

provider "aws" {
  region  = "ap-southeast-2"
}


module "stackstorm" {
  source                        = "../../modules/stackstorm"
  instance_type                 = "t2.medium"
  name_suffix                   = "_prod"
  availability_zone             = "ap-southeast-2a"
  root_domain                   = "prod.umccr.org"
  stackstorm_sub_domain         = "stackstorm"
  stackstorm_data_volume_name   = "stackstorm-data-prod" # NOTE: volume must exist
  stackstorm_docker_volume_name = "stackstorm-docker-volumes-prod" # NOTE: volume must exist
  # st2_hostname                  = "umccr-stackstorm-prod" # NOTE: if empty no DataDog agent is started
  st2_hostname                  = ""
  # ami_filters                   = "${var.ami_filters}" # can be used to overwrite the default AMI lookup
}

terraform {
  backend "s3" {
    bucket  = "umccr-terraform-states"
    key     = "stackstorm/terraform.tfstate"
    region  = "ap-southeast-2"
  }
}

variable "workspace_iam_roles" {
  default = {
    prod = "arn:aws:iam::472057503814:role/ops-admin"
  }
}

provider "aws" {
  region      = "ap-southeast-2"
  assume_role {
    role_arn     = "${var.workspace_iam_roles[terraform.workspace]}"
  }
}


module "stackstorm" {
  source                        = "../../modules/stackstorm"
  instance_type                 = "t2.medium"
  name_suffix                   = "_test"
  availability_zone             = "ap-southeast-2a"
  root_domain                   = "test.umccr.org"
  stackstorm_sub_domain         = "stackstorm"
  stackstorm_data_volume_name   = "stackstorm-data-test" # NOTE: volume must exist
  stackstorm_docker_volume_name = "stackstorm-docker-volumes-test" # NOTE: volume must exist
  # st2_hostname                  = "umccr-stackstorm-prod" # NOTE: if empty no DataDog agent is started
  st2_hostname                  = ""
  # ami_filters                   = "${var.ami_filters}" # can be used to overwrite the default AMI lookup
}

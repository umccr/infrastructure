terraform {
  backend "s3" {
    bucket  = "umccr-terraform-prod"
    key     = "stackstorm/terraform.tfstate"
    region  = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region  = "ap-southeast-2"
}


module "YOUR_STACK" {
  source                        = "../../modules/stackstorm"
  instance_type                 = "t2.medium"
  name_suffix                   = "_prod"
  availability_zone             = "ap-southeast-2a"
  root_domain                   = "prod.umccr.org"
  sub_domain					= "YOUR_STACK"
}

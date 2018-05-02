terraform {
  backend "s3" {
    bucket  = "umccr-terraform-states"
    key     = "bootstrap/terraform.tfstate"
    region  = "ap-southeast-2"
  }
}

provider "aws" {
  region      = "ap-southeast-2"
}


resource "aws_dynamodb_table" "dynamodb-terraform-lock" {
   name = "terraform-state-lock"
   hash_key = "LockID"
   read_capacity = 20
   write_capacity = 20

   attribute {
      name = "LockID"
      type = "S"
   }

   tags {
     Name = "Terraform Lock Table"
   }
}

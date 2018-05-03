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


################################################################################
## dev only resources

resource "aws_iam_role" "ops_admin_no_mfa_role" {
  count              = "${terraform.workspace == "dev" ? 1 : 0}"
  name               = "ops_admin_no_mfa"
  path               = "/"
  assume_role_policy = "${file("policies/assume_ops_admin_no_mfa_role.json")}"
}

resource "aws_iam_policy_attachment" "admin_access_to_ops_admin_no_mfa_role_attachment" {
    count      = "${terraform.workspace == "dev" ? 1 : 0}"
    name       = "admin_access_to_ops_admin_no_mfa_role_attachment"
    policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    groups     = []
    users      = []
    roles      = [ "${aws_iam_role.ops_admin_no_mfa_role.name}" ]
}

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

## Terraform resources #############################################################

# DynamoDB table for Terraform state locking
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

## General resources #############################################################

# S3 bucket to hold primary data
resource "aws_s3_bucket" "primary_data" {
  bucket = "${var.workspace_primary_data_bucket_name[terraform.workspace]}"
  acl    = "private"

  tags {
    Name        = "primary-data"
    Environment = "${terraform.workspace}"
  }
}

# S3 bucket for PCGR
# NOTE: this could possibly be removed if instead data is directly retrieved from the primary-data bucket
#       (but that requires major refactoring of the PCGR workflow)
resource "aws_s3_bucket" "pcgr_s3_bucket" {
  bucket = "${var.workspace_pcgr_bucket_name[terraform.workspace]}"

  lifecycle_rule {
    id      = "pcgr_expire_uploads"
    enabled = true

    transition {
      days          = 0
      storage_class = "ONEZONE_IA"
    }

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      days = 7
    }
  }
}



## Vault resources #############################################################

# S3 bucket as Vault backend store
resource "aws_s3_bucket" "vault" {
  bucket = "${var.workspace_vault_bucket_name[terraform.workspace]}"
  acl    = "private"

  tags {
    Name        = "vault-data"
    Environment = "${terraform.workspace}"
  }
}

# EC2 instance to run Vault server
data "aws_ami" "vault_ami" {
  most_recent      = true
  owners           = [ "620123204273" ]
  executable_users = [ "self" ]
  name_regex = "^vault-ami*"
}
resource "aws_spot_instance_request" "vault" {
  spot_price             = "${var.vault_instance_spot_price}"
  wait_for_fulfillment   = true

  ami                    = "${data.aws_ami.vault_ami.id}"
  instance_type          = "${var.vault_instance_type}"
  availability_zone      = "${var.vault_availability_zone}"
  iam_instance_profile   = "${aws_iam_instance_profile.vault.id}"
  subnet_id              = "${aws_subnet.vault_subnet_a.id}"
  vpc_security_group_ids = [ "${aws_security_group.vault.id}" ]

  monitoring             = true
  user_data              = "${data.template_file.userdata.rendered}"

  root_block_device {
      volume_type           = "gp2"
      volume_size           = 8
      delete_on_termination = true
  }

  # tags apply to the spot request, NOT the instance!
  # https://github.com/terraform-providers/terraform-provider-aws/issues/174
  # https://github.com/hashicorp/terraform/issues/3263#issuecomment-284387578
  tags {
    Name = "vault-server-request"
  }
}
data "template_file" "userdata" {
    template = "${file("${path.module}/templates/userdata.tpl")}"
    vars {
        allocation_id = "${aws_eip.vault.id}"
        bucket_name   = "${aws_s3_bucket.vault.id}"
        vault_domain  = "${aws_route53_record.vault.fqdn}"
    }
}

# Vault instance policies - instance profile
resource "aws_iam_instance_profile" "vault" {
  role = "${aws_iam_role.vault.name}"
}
resource "aws_iam_role" "vault" {
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.vault_assume_policy.json}"
}
data "aws_iam_policy_document" "vault_assume_policy" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = [ "ec2.amazonaws.com" ]
    }
  }
}
data "template_file" "vault_s3_policy" {
    template = "${file("policies/vault-s3-policy.json")}"
    vars {
        bucket_name = "${aws_s3_bucket.vault.id}"
    }
}
resource "aws_iam_policy" "vault_s3_policy" {
  path   = "/"
  policy = "${data.template_file.vault_s3_policy.rendered}"
}
resource "aws_iam_policy_attachment" "vault_s3_policy_attachment" {
    name       = "vault_s3_policy_attachment${var.workspace_name_suffix[terraform.workspace]}"
    policy_arn = "${aws_iam_policy.vault_s3_policy.arn}"
    groups     = []
    users      = []
    roles      = [ "${aws_iam_role.vault.name}" ]
}
resource "aws_iam_policy" "vault_ec2_policy" {
  path   = "/"
  policy = "${file("policies/vault_ec2_policy.json")}"
}
resource "aws_iam_policy_attachment" "vault_ec2_policy_attachment" {
    name       = "vault_ec2_policy_attachment${var.workspace_name_suffix[terraform.workspace]}"
    policy_arn = "${aws_iam_policy.vault_ec2_policy.arn}"
    groups     = []
    users      = []
    roles      = [ "${aws_iam_role.vault.name}" ]
}

# Vault network
resource "aws_vpc" "vault" {
    cidr_block           = "172.31.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true
    instance_tenancy     = "default"

    tags {
      Name = "vpc_vault${var.workspace_name_suffix[terraform.workspace]}"
    }
}
resource "aws_subnet" "vault_subnet_a" {
    vpc_id                  = "${aws_vpc.vault.id}"
    cidr_block              = "172.31.0.0/20"
    map_public_ip_on_launch = true
    availability_zone       = "${var.vault_availability_zone}"

    tags {
      Name = "vault_subnet_a${var.workspace_name_suffix[terraform.workspace]}"
    }
}
resource "aws_security_group" "vault" {
    description = "Security group for Vault VPC"
    vpc_id      = "${aws_vpc.vault.id}"

    # required for letsencrypt
    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        cidr_blocks     = [ "0.0.0.0/0" ]
    }

    # port for vault communication
    ingress {
        from_port       = 8200
        to_port         = 8200
        protocol        = "tcp"
        cidr_blocks     = [ "0.0.0.0/0" ]
    }

    ingress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        self            = true
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = [ "0.0.0.0/0" ]
        ipv6_cidr_blocks = [ "::/0" ]
    }

}

resource "aws_eip" "vault" {
  vpc         = true
  depends_on  = ["aws_internet_gateway.vault"]
}
resource "aws_internet_gateway" "vault" {
  vpc_id = "${aws_vpc.vault.id}"

  tags {
    Name = "vpc_vault_gw${var.workspace_name_suffix[terraform.workspace]}"
  }
}
resource "aws_route_table" "vault" {
  vpc_id = "${aws_vpc.vault.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.vault.id}"
  }
}
resource "aws_route_table_association" "vault" {
  subnet_id = "${aws_subnet.vault_subnet_a.id}"
  route_table_id = "${aws_route_table.vault.id}"
}
data "aws_route53_zone" "umccr_org" {
  name         = "${var.workspace_root_domain[terraform.workspace]}."
}
resource "aws_route53_record" "vault" {
  zone_id = "${data.aws_route53_zone.umccr_org.zone_id}"
  name    = "${var.vault_sub_domain}.${data.aws_route53_zone.umccr_org.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.vault.public_ip}"]
}


################################################################################
##     dev only resources                                                     ##
################################################################################

# Add a ops-admin rold that can be assumed without MFA (used for build agents)
resource "aws_iam_role" "ops_admin_no_mfa_role" {
  count              = "${terraform.workspace == "dev" ? 1 : 0}"
  name               = "ops_admin_no_mfa"
  path               = "/"
  assume_role_policy = "${file("policies/assume_ops_admin_no_mfa_role.json")}"
}
resource "aws_iam_policy" "ops_admin_no_mfa_policy" {
  path   = "/"
  policy = "${file("policies/ops_admin_no_mfa_policy.json")}"
}

resource "aws_iam_policy_attachment" "admin_access_to_ops_admin_no_mfa_role_attachment" {
    count      = "${terraform.workspace == "dev" ? 1 : 0}"
    name       = "admin_access_to_ops_admin_no_mfa_role_attachment"
    policy_arn = "${aws_iam_policy.ops_admin_no_mfa_policy.arn}"
    groups     = []
    users      = []
    roles      = [ "${aws_iam_role.ops_admin_no_mfa_role.name}" ]
}

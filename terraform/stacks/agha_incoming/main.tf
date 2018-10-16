# NOTE: AWS profile is hard coded for convenience
terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "agha_incoming/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
    profile        = "umccr_ops_admin_no_mfa"
  }
}

provider "aws" {
  region  = "${var.aws_region}"
  profile = "umccr_ops_admin_no_mfa"
}

################################################################################
# EC2 instance setup to access data in s3://agha-gdr-staging-dev
data "template_file" "userdata" {
  template = "${file("${path.module}/templates/userdata.tpl")}"

  vars {
    AGHA_BUCKET   = "${var.workspace_agha_staging_bucket[terraform.workspace]}"
    INSTANCE_TAGS = "${jsonencode(var.workspace_instance_tags[terraform.workspace])}"
  }
}

resource "aws_spot_instance_request" "stackstorm_instance" {
  spot_price           = "${var.instance_spot_price}"
  wait_for_fulfillment = true

  ami                  = "${var.instance_ami}"
  instance_type        = "${var.instance_type}"
  availability_zone    = "${var.availability_zone}"
  iam_instance_profile = "${aws_iam_instance_profile.instance_profile.id}"

  #   subnet_id              = "${aws_subnet.sn_a_vpc_st2.id}"
  #   vpc_security_group_ids = [ "${aws_security_group.vpc_st2.id}" ]

  user_data = "${data.template_file.userdata.rendered}"
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 10
    delete_on_termination = true
  }
  # tags apply to the spot request, NOT the instance!
  # https://github.com/terraform-providers/terraform-provider-aws/issues/174
  # https://github.com/hashicorp/terraform/issues/3263#issuecomment-284387578
  tags {
    Name = "${var.stack_name}_spot_request_${terraform.workspace}"
  }
}

################################################################################
# EC2 instance profile
resource "aws_iam_instance_profile" "instance_profile" {
  role = "${aws_iam_role.instance_profile.name}"
}

resource "aws_iam_role" "instance_profile" {
  name = "${var.stack_name}_instance_role_${terraform.workspace}"
  path = "/${var.stack_name}/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = "${file("policies/instance-profile.json")}"

  vars {
    resources = "${jsonencode(var.workspace_agha_buckets[terraform.workspace])}"
  }
}

resource "aws_iam_policy" "instance_profile" {
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.instance_profile.rendered}"
}

resource "aws_iam_role_policy_attachment" "instance_profile" {
  role       = "${aws_iam_role.instance_profile.name}"
  policy_arn = "${aws_iam_policy.instance_profile.arn}"
}

################################################################################


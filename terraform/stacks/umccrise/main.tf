terraform {
  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "umccrise/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  # AWS access credentials are retrieved from env variables
  region = "ap-southeast-2"
}

resource "aws_security_group" "batch" {
  name   = "${var.stack_name}_batch_compute_environment_security_group_${terraform.workspace}"
  vpc_id = "${aws_vpc.batch.id}"

      # allow SSH access (during development)
      ingress {
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = [ "0.0.0.0/0" ]
        ipv6_cidr_blocks = [ "::/0" ]
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

resource "aws_vpc" "batch" {
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags {
    Name  = "${var.stack_name}_vpc_${terraform.workspace}"
    stack = "${var.stack_name}"
  }

}

################################################################################
# allow SSH access (during development)
resource "aws_subnet" "batch" {
  vpc_id            = "${aws_vpc.batch.id}"
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.availability_zone}"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "batch" {
  vpc_id = "${aws_vpc.batch.id}"

  tags {
    Name = "${var.stack_name}_gateway_${terraform.workspace}"
  }
}

resource "aws_route_table" "batch" {
  vpc_id = "${aws_vpc.batch.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.batch.id}"
  }
}

resource "aws_route_table_association" "batch" {
  subnet_id = "${aws_subnet.batch.id}"
  route_table_id = "${aws_route_table.batch.id}"
}


################################################################################
# set up the compute environment
module "compute_env" {
  # NOTE: the source cannot be interpolated, so we can't use a variable here and have to keep the difference bwtween production and developmment in a branch
  source             = "../../modules/batch"
  availability_zone  = "ap-southeast-2"
  name_suffix        = "_${terraform.workspace}"
  stack_name         = "${var.stack_name}"
  compute_env_name   = "${var.stack_name}_compute_env_${terraform.workspace}"
  image_id           = "${var.umccrise_image_id}"
  instance_types     = ["m4.large"]
  security_group_ids = ["${aws_security_group.batch.id}"]
  subnet_ids         = ["${aws_subnet.batch.id}"]
  umccrise_buckets   = "${var.workspace_umccrise_buckets[terraform.workspace]}"
}

resource "aws_batch_job_queue" "umccr_batch_queue" {
  name                 = "${var.stack_name}_batch_queue_${terraform.workspace}"
  state                = "ENABLED"
  priority             = 1
  compute_environments = ["${module.compute_env.compute_env_arn}"]
}

## Job definitions

resource "aws_batch_job_definition" "umccrise_standard" {
  name                 = "${var.stack_name}_job_${terraform.workspace}"
  type                 = "container"
  container_properties = "${file("jobs/umccrise_GRCh37_job.json")}"
}

resource "aws_batch_job_definition" "sleeper" {
  name                 = "${var.stack_name}_sleeper_${terraform.workspace}"
  type                 = "container"
  container_properties = "${file("jobs/sleeper_job.json")}"
}

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
  name   = "aws_batch_compute_environment_security_group${var.workspace_name_suffix[terraform.workspace]}"
  vpc_id = "${aws_vpc.batch.id}"
}

resource "aws_vpc" "batch" {
  cidr_block = "10.1.0.0/16"
}

resource "aws_subnet" "batch" {
  vpc_id            = "${aws_vpc.batch.id}"
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.availability_zone}"
}

module "compute_env" {
  # NOTE: the source cannot be interpolated, so we can't use a variable here and have to keep the difference bwtween production and developmment in a branch
  source             = "../../modules/batch"
  availability_zone  = "ap-southeast-2"
  name_suffix        = "${var.workspace_name_suffix[terraform.workspace]}"
  compute_env_name   = "umccrise_compute_env${var.workspace_name_suffix[terraform.workspace]}"
  image_id           = "ami-0e72b22a59e4345aa"
  instance_types     = ["m4.large"]
  security_group_ids = ["${aws_security_group.batch.id}"]
  subnet_ids         = ["${aws_subnet.batch.id}"]
}

resource "aws_batch_job_queue" "umccr_batch_queue" {
  name                 = "umccr_batch_queue${var.workspace_name_suffix[terraform.workspace]}"
  state                = "ENABLED"
  priority             = 1
  compute_environments = ["${module.compute_env.batch.compute_env_arn}"]
}

## Job definitions

resource "aws_batch_job_definition" "test" {
  name                 = "umccrise_job${var.workspace_name_suffix[terraform.workspace]}"
  type                 = "container"
  container_properties = "${file("jobs/umccrise_job.json")}"
}

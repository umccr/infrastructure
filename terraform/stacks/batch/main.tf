resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "ec2.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_policy" "umccr_container_role" {
  path   = "/"
  policy = "${file("policies/AmazonEC2ContainerServiceforEC2Role.json")}"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = "${aws_iam_role.ecs_instance_role.name}"
  policy_arn = "${aws_iam_policy.umccr_container_role.arn}"
}

resource "aws_iam_instance_profile" "ecs_instance_role" {
  name = "ecs_instance_role"
  role = "${aws_iam_role.ecs_instance_role.name}"
}

resource "aws_iam_role" "aws_batch_service_role" {
  name = "aws_batch_service_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "batch.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_role" "aws_spotfleet_service_role" {
  name = "aws_spotfleet_service_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "spotfleet.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_policy" "umccr_spotfleet" {
  path   = "/"
  policy = "${file("policies/AmazonEC2SpotFleetTaggingRole.json")}"
}

resource "aws_iam_role_policy_attachment" "aws_spotfleet_service_role" {
  role       = "${aws_iam_role.aws_spotfleet_service_role.name}"
  policy_arn = "${aws_iam_policy.umccr_spotfleet.arn}"
}

resource "aws_iam_policy" "umccr_batch_role" {
  path   = "/"
  policy = "${file("policies/AWSBatchServiceRole.json")}"
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = "${aws_iam_role.aws_batch_service_role.name}"
  policy_arn = "${aws_iam_policy.umccr_batch_role.arn}"
}

resource "aws_security_group" "batch" {
  name   = "aws_batch_compute_environment_security_group"
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

resource "aws_batch_compute_environment" "batch" {
  compute_environment_name = "umccr_aws_batch_dev"

  compute_resources {
    instance_role = "${aws_iam_instance_profile.ecs_instance_role.arn}"
    image_id      = "ami-0e72b22a59e4345aa"                             # XXX: umccrise AMI for now

    instance_type = [
      "m4.large",
    ]

    max_vcpus     = 16
    desired_vcpus = 8
    min_vcpus     = 0

    security_group_ids = [
      "${aws_security_group.batch.id}",
    ]

    subnets = [
      "${aws_subnet.batch.id}",
    ]

    tags = {
      Name = "batch"
    }

    spot_iam_fleet_role = "${aws_iam_role.aws_spotfleet_service_role.arn}"
    type                = "SPOT"
    bid_percentage      = 50
  }

  service_role = "${aws_iam_role.aws_batch_service_role.arn}"
  type         = "MANAGED"
  depends_on   = ["aws_iam_role_policy_attachment.aws_batch_service_role"]
}

## Create job queue

resource "aws_batch_job_queue" "umccr_batch_queue" {
  name                 = "umccr_batch_queue"
  state                = "ENABLED"
  priority             = 1
  compute_environments = ["${aws_batch_compute_environment.batch.arn}"]
}

## Job definitions

resource "aws_batch_job_definition" "test" {
  name                 = "umccrise_job"
  type                 = "container"
  container_properties = "${file("jobs/umccrise_job.json")}"
}

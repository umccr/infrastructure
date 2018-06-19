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

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = "${aws_iam_role.ecs_instance_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
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

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = "${aws_iam_role.aws_batch_service_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_security_group" "umccrise" {
  name = "aws_batch_compute_environment_security_group"
}

resource "aws_vpc" "umccrise" {
  cidr_block = "10.1.0.0/16"
}

resource "aws_subnet" "umccrise" {
  vpc_id     = "${aws_vpc.umccrise.id}"
  cidr_block = "10.1.1.0/24"
}

resource "aws_batch_compute_environment" "umccrise" {
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
      "${aws_security_group.umccrise.id}",
    ]

    subnets = [
      "${aws_subnet.umccrise.id}",
    ]

    tags = {
      Name = "umccrise"
    }

    type           = "SPOT"
    bid_percentage = 50
  }

  service_role = "${aws_iam_role.aws_batch_service_role.arn}"
  type         = "MANAGED"
  depends_on   = ["aws_iam_role_policy_attachment.aws_batch_service_role"]
}

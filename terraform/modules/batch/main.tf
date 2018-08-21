# TODO: check used resource names are unique enough to not clash with other stacks
################################################################################
# create ECS instance profile for compute resources
data "aws_iam_policy_document" "assume_role_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name               = "ecs_instance_role${var.name_suffix}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_ec2.json}"
}

resource "aws_iam_policy" "umccr_container_service_policy" {
  name   = "umccr_container_service_policy${var.name_suffix}"
  path   = "/"
  policy = "${file("${path.module}/policies/AmazonEC2ContainerServiceforEC2Role.json")}"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = "${aws_iam_role.ecs_instance_role.name}"
  policy_arn = "${aws_iam_policy.umccr_container_service_policy.arn}"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile${var.name_suffix}"
  role = "${aws_iam_role.ecs_instance_role.name}"
}

################################################################################
# create compute environment service role

data "aws_iam_policy_document" "assume_role_batch" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_batch_service_role" {
  name               = "aws_batch_service_role${var.name_suffix}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_batch.json}"
}

resource "aws_iam_policy" "umccr_batch_policy" {
  name   = "umccr_batch_policy${var.name_suffix}"
  path   = "/"
  policy = "${file("${path.module}/policies/AWSBatchServiceRole.json")}"
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = "${aws_iam_role.aws_batch_service_role.name}"
  policy_arn = "${aws_iam_policy.umccr_batch_policy.arn}"
}

################################################################################
# create SPOT fleet service role

data "aws_iam_policy_document" "assume_role_spotfleet" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["spotfleet.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_spotfleet_service_role" {
  name               = "aws_spotfleet_service_role${var.name_suffix}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_spotfleet.json}"
}

resource "aws_iam_policy" "umccr_spotfleet_policy" {
  name   = "umccr_spotfleet_policy${var.name_suffix}"
  path   = "/"
  policy = "${file("${path.module}/policies/AmazonEC2SpotFleetTaggingRole.json")}"
}

resource "aws_iam_role_policy_attachment" "aws_spotfleet_service_role" {
  role       = "${aws_iam_role.aws_spotfleet_service_role.name}"
  policy_arn = "${aws_iam_policy.umccr_spotfleet_policy.arn}"
}

################################################################################
# create ECS compute environment

resource "aws_batch_compute_environment" "batch" {
  compute_environment_name = "${var.compute_env_name}"

  compute_resources {
    instance_role = "${aws_iam_instance_profile.ecs_instance_profile.arn}"
    image_id      = "${var.image_id}"

    instance_type = "${var.instance_types}"

    max_vcpus     = "${var.max_vcpus}"
    desired_vcpus = "${var.desired_vcpus}"
    min_vcpus     = "${var.min_vcpus}"

    security_group_ids = ["${var.security_group_ids}"]

    subnets = ["${var.subnet_ids}"]

    tags = {
      Name = "batch"
    }

    spot_iam_fleet_role = "${aws_iam_role.aws_spotfleet_service_role.arn}"
    type                = "SPOT"
    bid_percentage      = "${var.spot_bid_percent}"
  }

  service_role = "${aws_iam_role.aws_batch_service_role.arn}"
  type         = "MANAGED"
  depends_on   = ["aws_iam_role_policy_attachment.aws_batch_service_role", 
                  "aws_iam_instance_profile.ecs_instance_profile", 
                  "aws_iam_role.aws_spotfleet_service_role"]
}

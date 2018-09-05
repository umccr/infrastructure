# TODO: check used resource names are unique enough to not clash with other stacks
################################################################################
# create ECS instance profile for compute resources

resource "aws_iam_instance_profile" "ecsInstanceRole" {
  name = "${aws_iam_role.ecsInstanceRole.name}"
  role = "${aws_iam_role.ecsInstanceRole.name}"
  # NOTE: AWS batch does not support profiles with non-root path!
  path = "/"
  # make sure the policy is attached before creating the profile
  depends_on   = ["aws_iam_role_policy_attachment.ecsInstanceRole"]
}

resource "aws_iam_role" "ecsInstanceRole" {
  name = "${var.stack_name}_ecsInstanceRole${var.name_suffix}"
  path = "/${var.stack_name}/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

data "template_file" "ecsInstanceRole" {
  template = "${file("${path.module}/policies/ec2-instance-role.json")}"

  vars {
    resources = "${jsonencode(var.umccrise_buckets)}"
  }
}

resource "aws_iam_policy" "ecsInstanceRole" {
  name   = "umccr_batch_ecsInstanceRole${var.name_suffix}"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.ecsInstanceRole.rendered}"
}

resource "aws_iam_role_policy_attachment" "ecsInstanceRole" {
  role = "${aws_iam_role.ecsInstanceRole.name}"
  policy_arn = "${aws_iam_policy.ecsInstanceRole.arn}"
}

################################################################################
# create compute environment service role

resource "aws_iam_role" "AWSBatchServiceRole" {
  name = "${var.stack_name}_AWSBatchServiceRole${var.name_suffix}"
  path = "/${var.stack_name}/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "batch.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AWSBatchServiceRole" {
  role = "${aws_iam_role.AWSBatchServiceRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

################################################################################
# create SPOT fleet service role

resource "aws_iam_role" "AmazonEC2SpotFleetTaggingRole" {
  name = "${var.stack_name}_AmazonEC2SpotFleetTaggingRole${var.name_suffix}"
  path = "/${var.stack_name}/"
  description = "Role to Allow EC2 Spot Fleet to request and terminate Spot Instances on your behalf."
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "spotfleet.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEC2SpotFleetTaggingRole" {
  role = "${aws_iam_role.AmazonEC2SpotFleetTaggingRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

################################################################################
# create ECS compute environment

resource "aws_batch_compute_environment" "batch" {
  compute_environment_name = "${var.compute_env_name}"

  compute_resources {
    instance_role = "${aws_iam_instance_profile.ecsInstanceRole.arn}"
    image_id      = "${var.image_id}"

    instance_type = "${var.instance_types}"

    max_vcpus     = "${var.max_vcpus}"
    desired_vcpus = "${var.desired_vcpus}"
    min_vcpus     = "${var.min_vcpus}"

    security_group_ids = ["${var.security_group_ids}"]

    subnets = ["${var.subnet_ids}"]

    tags = {
      Name  = "batch"
      stack = "${var.stack_name}"
    }

    spot_iam_fleet_role = "${aws_iam_role.AmazonEC2SpotFleetTaggingRole.arn}"
    type                = "SPOT"
    bid_percentage      = "${var.spot_bid_percent}"
  }

  service_role = "${aws_iam_role.AWSBatchServiceRole.arn}"
  type         = "MANAGED"
  depends_on   = ["aws_iam_role_policy_attachment.AWSBatchServiceRole", 
                  "aws_iam_role_policy_attachment.AmazonEC2SpotFleetTaggingRole",
                  "aws_iam_instance_profile.ecsInstanceRole"
                  ]
}


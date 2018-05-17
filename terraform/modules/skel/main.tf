resource "aws_iam_role" "YOUR_MODULE_role" {
  name               = "YOUR_MODULE_role${var.name_suffix}"                             # optional
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.YOUR_MODULE_assume_policy.json}"
}

data "aws_iam_policy_document" "YOUR_MODULE_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "s3_YOUR_MODULE_policy" {
  name   = "s3_YOUR_MODULE_policy${var.name_suffix}"                       # optional
  path   = "/"
  policy = "${file("${path.module}/policies/s3_YOUR_MODULE_policy.json")}"
}

resource "aws_iam_policy_attachment" "s3_policy_to_YOUR_MODULE_role_attachment" {
  name       = "s3_policy_to_YOUR_MODULE_role_attachment${var.name_suffix}" # required
  policy_arn = "${aws_iam_policy.s3_YOUR_MODULE_policy.arn}"
  groups     = []
  users      = []
  roles      = ["${aws_iam_role.YOUR_MODULE_role.name}"]
}

resource "aws_iam_policy" "ec2_YOUR_MODULE_policy" {
  name   = "ec2_YOUR_MODULE_policy${var.name_suffix}"                       # optional
  path   = "/"
  policy = "${file("${path.module}/policies/ec2_YOUR_MODULE_policy.json")}"
}

resource "aws_iam_policy_attachment" "ec2_policy_to_YOUR_MODULE_role_attachment" {
  name       = "ec2_policy_to_YOUR_MODULE_role_attachment${var.name_suffix}" # required
  policy_arn = "${aws_iam_policy.ec2_YOUR_MODULE_policy.arn}"
  groups     = []
  users      = []
  roles      = ["${aws_iam_role.YOUR_MODULE_role.name}"]
}

data "aws_ami" "YOUR_MODULE_ami" {
  most_recent = true
  owners      = ["self"]

  filter = "${var.ami_filters}"
}

resource "aws_spot_instance_request" "YOUR_MODULE_instance" {
  spot_price           = "0.018" # t2.medium: 0.0175 (current value)
  wait_for_fulfillment = true

  ami                    = "${data.aws_ami.YOUR_MODULE_ami.id}"
  instance_type          = "${var.instance_type}"
  availability_zone      = "${var.availability_zone}"
  iam_instance_profile   = "${aws_iam_instance_profile.YOUR_MODULE_instance_profile.id}"
  subnet_id              = "${aws_subnet.sn_a_vpc_st2.id}"
  vpc_security_group_ids = ["${aws_security_group.vpc_st2.id}"]

  monitoring = true
  user_data  = "${data.template_file.launch-config-userdata.rendered}"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  # tags apply to the spot request, NOT the instance!
  # https://github.com/terraform-providers/terraform-provider-aws/issues/174
  # https://github.com/hashicorp/terraform/issues/3263#issuecomment-284387578
  tags {
    Name = "YOUR_MODULE${var.name_suffix}"
  }
}

data "template_file" "launch-config-userdata" {
  template = "${file("${path.module}/template-files/launch-config-userdata.tpl")}"

  vars {
    allocation_id = "${aws_eip.YOUR_MODULE.id}"
    st2_hostname  = "${var.st2_hostname}"
  }
}

resource "aws_iam_instance_profile" "YOUR_MODULE_instance_profile" {
  # name  = "YOUR_MODULE_instance_profile${var.name_suffix}" # optional
  role = "${aws_iam_role.YOUR_MODULE_role.name}"
}

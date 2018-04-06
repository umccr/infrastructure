terraform {
  backend "s3" {
    bucket  = "umccr-terraform-prod"
    key     = "stackstorm/terraform.tfstate"
    region  = "ap-southeast-2"
  }
}

provider "aws" {
  region  = "${var.aws_region}"
}

resource "aws_iam_role" "stackstorm_role" {
  name               = "stackstorm_role"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.stackstorm_assume_policy.json}"
}
data "aws_iam_policy_document" "stackstorm_assume_policy" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = [ "ec2.amazonaws.com" ]
    }
  }
}


resource "aws_iam_policy" "s3_stackstorm_policy" {
  name   = "s3_stackstorm_policy"
  path   = "/"
  policy = "${file("policies/s3_stackstorm_policy.json")}"
}

resource "aws_iam_policy_attachment" "s3_policy_to_stackstorm_role_attachment" {
    name       = "s3_policy_to_stackstorm_role_attachment"
    policy_arn = "${aws_iam_policy.s3_stackstorm_policy.arn}"
    groups     = []
    users      = []
    roles      = [ "${aws_iam_role.stackstorm_role.name}" ]
}

resource "aws_iam_policy" "ec2_stackstorm_policy" {
  name   = "ec2_stackstorm_policy"
  path   = "/"
  policy = "${file("policies/ec2_stackstorm_policy.json")}"
}

resource "aws_iam_policy_attachment" "ec2_policy_to_stackstorm_role_attachment" {
    name       = "ec2_policy_to_stackstorm_role_attachment"
    policy_arn = "${aws_iam_policy.ec2_stackstorm_policy.arn}"
    groups     = []
    users      = []
    roles      = [ "${aws_iam_role.stackstorm_role.name}" ]
}


resource "aws_autoscaling_group" "asg_arteria" {
    name                      = "asg_arteria_${aws_launch_configuration.lc_arteria.name}"
    desired_capacity          = 1
    max_size                  = 1
    min_size                  = 1
    health_check_grace_period = 300
    health_check_type         = "EC2"
    launch_configuration      = "${aws_launch_configuration.lc_arteria.name}"
    vpc_zone_identifier       = [ "${aws_subnet.sn_a_vpc_st2.id}" ]

    tag {
        key   = "Name"
        value = "arteria"
        propagate_at_launch = true
    }

}

resource "aws_launch_configuration" "lc_arteria" {
    name_prefix                 = "lc_arteria_"
    # image_id                    = "ami-9d4281ff" # only docker and stackstorm, no rexray etc
    # image_id                    = "ami-f8ae639a" # docker + rexray/ebs plugin + s3fs + awscli + stackstorm (with prebuild st2 base image and pre-loaded images)
    # image_id                    = "ami-38e8255a" # docker + rexray/ebs plugin + s3fs + awscli + stackstorm (with prebuild st2 base image and pre-loaded images) + docker-compose-up.sh + localtime
    # image_id                    = "ami-81d21fe3" # docker + rexray/ebs plugin + rexray + s3fs + awscli + stackstorm (with prebuild st2 base image and pre-loaded images) + docker-compose-up.sh + localtime
    # image_id                    = "ami-b7ba76d5" # docker + rexray/ebs plugin + s3fs + awscli + stackstorm (with prebuild st2 base image and pre-loaded images) + docker-compose-up.sh + localtime (newer base AMI)
    image_id                    = "ami-b9b678db" # docker + rexray/ebs plugin + s3fs + awscli + stackstorm (with prebuild st2 base image and pre-loaded images) + docker-compose-up.sh + localtime (newer base AMI)
    instance_type               = "t2.medium"
    iam_instance_profile        = "${aws_iam_instance_profile.stackstorm_instance_profile.id}"
    security_groups             = [ "${aws_security_group.vpc_st2.id}" ]
    # ebs_optimized               = true
    spot_price                  = "0.018" # t2.medium: 0.0175 (current value)
    # spot_price                  = "0.03" # m5.large: 0.0282 (current value) ebs_optimized=true
    # spot_price                  = "0.07" # m4.xlarge: 0.0644 (current value) ebs_optimized=true

    user_data = "${data.template_file.lc_userdata.rendered}" # see: http://roshpr.net/blog/2016/10/terraform-using-user-data-in-launch-configuration/

    # TODO: this approach is not very flexible: https://heapanalytics.com/blog/engineering/terraform-gotchas
    root_block_device {
        volume_type           = "gp2"
        volume_size           = 20
        delete_on_termination = true
    }
    ebs_block_device {
        device_name           = "/dev/sdf"
        volume_type           = "gp2"
        volume_size           = 1
        iops                  = 300
        snapshot_id           = "${data.aws_ebs_snapshot.st2_ebs_volume.snapshot_id}"
        delete_on_termination = true
    }

    lifecycle { create_before_destroy = true }
}
data "template_file" "lc_userdata" {
    template = "${file("template-files/lc-userdata.tpl")}"
    vars {
        allocation_id = "${aws_eip.stackstorm.id}"
    }
}
data "aws_ebs_snapshot" "st2_ebs_volume" {
  most_recent = true
  owners      = [ "self" ]

  filter {
    name   = "tag:Name"
    values = [ "stackstorm-config-2018-03-13" ]
  }
}


resource "aws_iam_instance_profile" "stackstorm_instance_profile" {
  name  = "stackstorm_instance_profile"
  role = "${aws_iam_role.stackstorm_role.name}"
}

# resource "aws_route53_zone" "dev" {
#   name = "umccrdev.nopcode.org"
# }
#
# resource "aws_route53_record" "stackstorm_dev" {
#   zone_id = "${aws_route53_zone.dev.zone_id}"
#   name    = "stackstorm.umccrdev.nopcode.org"
#   type    = "CNAME"
#   ttl     = "300"
#   records = ["${aws_eip.stackstorm.public_ip}"]
# }

resource "aws_eip" "stackstorm" {
  vpc         = true
  depends_on  = ["aws_internet_gateway.vpc_st2"]
}

data "aws_route53_zone" "umccr_org" {
  name         = "umccr.org."
}

resource "aws_route53_record" "st2_dev" {
  zone_id = "${data.aws_route53_zone.umccr_org.zone_id}"
  name    = "stackstorm.dev.${data.aws_route53_zone.umccr_org.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.stackstorm.public_ip}"]
}

resource "aws_vpc" "vpc_st2" {
    cidr_block           = "172.31.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true
    instance_tenancy     = "default"

    tags {
      Name = "vpc_st2"
    }
}

resource "aws_subnet" "sn_a_vpc_st2" {
    vpc_id                  = "${aws_vpc.vpc_st2.id}"
    cidr_block              = "172.31.0.0/20"
    availability_zone       = "${var.default_az}"
    map_public_ip_on_launch = true

    tags {
      Name = "sn_a_vpc_st2"
    }
}

resource "aws_internet_gateway" "vpc_st2" {
  vpc_id = "${aws_vpc.vpc_st2.id}"

  tags {
    Name = "vpc_st2_igw"
  }
}

resource "aws_route_table" "st2_rt" {
  vpc_id = "${aws_vpc.vpc_st2.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.vpc_st2.id}"
  }
}

# TODO: check if we need to associate the route table to the subnet or if it automatically applies to the wholw vpc
resource "aws_route_table_association" "st2_rt" {
  subnet_id = "${aws_subnet.sn_a_vpc_st2.id}"
  route_table_id = "${aws_route_table.st2_rt.id}"
}


resource "aws_security_group" "vpc_st2" {
    name        = "sg_vpc_st2"
    description = "Security group for st2 VPC"
    vpc_id      = "${aws_vpc.vpc_st2.id}"

    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        cidr_blocks     = [ "0.0.0.0/0" ]
    }

    ingress {
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = [ "0.0.0.0/0" ]
        ipv6_cidr_blocks = [ "::/0" ]
    }

    ingress {
        from_port       = 443
        to_port         = 443
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

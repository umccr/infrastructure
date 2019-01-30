# Create a new instance of the latest Ubuntu 14.04 on an
# t2.micro node with an AWS Tag naming it "mosdepth-skanwal"
provider "aws" {
  region = "ap-southeast-2"
  profile = "umccr_ops_admin_dev"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"

  tags = {
    Name = "mosdepth-skanwal"
  }
}

data "template_file" "userdata" {
  template = "${file("${path.module}/templates/userdata.tpl")}"

  vars {
    INSTANCE_TAGS = "${jsonencode(var.workspace_instance_tags[terraform.workspace])}"
  }
}

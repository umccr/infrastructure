terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "packer/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# packer_role: used to execute packer builder (and launch the builder EC2 instance)
resource "aws_iam_role" "packer_role" {
  name               = "packer_role"
  path               = "/"
  assume_role_policy = "${file("${path.module}/policies/assume_packer_role.json")}"
}

# packer_instance_profile: permissions passed to the packer created AWS EC2 instance
resource "aws_iam_instance_profile" "new_packer_instance_profile" {
  name = "new_packer_instance_profile"
  role = "${aws_iam_role.packer_role.name}"
}

# packer_umccrise_role: role to grant access to resources needed by umccrise volume builder
resource "aws_iam_role" "packer_umccrise_role" {
  name               = "packer_umccrise_role"
  path               = "/"
  assume_role_policy = "${file("${path.module}/policies/assume_packer_role.json")}"
}

# packer_instance_profile_umccrise: permissions passed to the packer created AWS EC2 instance for uccrise
resource "aws_iam_instance_profile" "packer_instance_profile_umccrise" {
  name = "packer_instance_profile_umccrise"
  role = "${aws_iam_role.packer_umccrise_role.name}"
}

resource "aws_iam_policy" "packer_ec2" {
  name   = "packer_ec2"
  path   = "/"
  policy = "${file("${path.module}/policies/packer_ec2.json")}"
}

resource "aws_iam_policy_attachment" "packer_ec2_policy_to_packer_role_attachment" {
  name       = "packer_ec2_policy_to_packer_role_attachment"
  policy_arn = "${aws_iam_policy.packer_ec2.arn}"
  groups     = []
  users      = []
  roles      = ["${aws_iam_role.packer_role.name}"]
}

resource "aws_iam_policy" "packer_umccrise" {
  name   = "packer_umccrise"
  path   = "/"
  policy = "${file("${path.module}/policies/packer_umccrise_role.json")}"
}

resource "aws_iam_policy_attachment" "packer_umccrise_policy_to_packer_role_attachment" {
  name       = "packer_umccrise_policy_to_packer_role_attachment"
  policy_arn = "${aws_iam_policy.packer_umccrise.arn}"
  groups     = []
  users      = []
  roles      = ["${aws_iam_role.packer_umccrise_role.name}"]
}

resource "aws_iam_policy" "packer_spotfleet" {
  path   = "/"
  policy = "${file("${path.module}/policies/AmazonEC2SpotFleetTaggingRole.json")}"
}

resource "aws_iam_policy_attachment" "spot_policy_to_packer_role_attachment" {
  name       = "spot_policy_to_packer_role_attachment"
  policy_arn = "${aws_iam_policy.packer_spotfleet.arn}"
  groups     = []
  users      = []
  roles      = ["${aws_iam_role.packer_role.name}"]
}

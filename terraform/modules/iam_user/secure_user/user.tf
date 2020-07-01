resource "aws_iam_user" "iam_user" {
  name          = "${var.username}"
  path          = "/"
  force_destroy = true
  tags = {
    email = "${var.email}"
  }
}

resource "aws_iam_access_key" "iam_access_key" {
  user    = "${aws_iam_user.iam_user.name}"
  pgp_key = "${var.pgp_key}"
}

data "template_file" "get_user_policy" {
  template = "${file("${path.module}/policies/get_user.json")}"

  vars {
    user_arn = "${aws_iam_user.iam_user.arn}"
  }
}

resource "aws_iam_policy" "get_user_policy" {
  path   = "/"
  policy = "${data.template_file.get_user_policy.rendered}"
}

resource "aws_iam_policy_attachment" "get_user_policy_attachment" {
  name       = "get_user_policy_attachment_${aws_iam_user.iam_user.name}"
  policy_arn = "${aws_iam_policy.get_user_policy.arn}"
  groups     = []
  users      = ["${aws_iam_user.iam_user.name}"]
  roles      = []
}

resource "aws_iam_user" "iam_user" {
  count         = "${length(keys(var.users))}"
  name          = "${element(keys(var.users), count.index)}"
  path          = "/"
  force_destroy = true
}

resource "aws_iam_access_key" "iam_access_key" {
  count      = "${length(keys(var.users))}"
  user       = "${element(keys(var.users), count.index)}"
  pgp_key    = "${element(values(var.users), count.index)}"
  depends_on = ["aws_iam_user.iam_user"]
}

data "template_file" "get_user_policy" {
  count    = "${length(keys(var.users))}"
  template = "${file("${path.module}/policies/get_user.json")}"

  vars {
    user_arn = "${aws_iam_user.iam_user.*.arn[count.index]}"
  }

  depends_on = ["aws_iam_user.iam_user"]
}

resource "aws_iam_policy" "get_user_policy" {
  count  = "${length(keys(var.users))}"
  path   = "/"
  policy = "${data.template_file.get_user_policy.*.rendered[count.index]}"
}

resource "aws_iam_policy_attachment" "get_user_policy_attachment" {
  count      = "${length(keys(var.users))}"
  name       = "get_user_policy_attachment_${aws_iam_user.iam_user.*.name[count.index]}"
  policy_arn = "${aws_iam_policy.get_user_policy.*.arn[count.index]}"
  groups     = []
  users      = ["${aws_iam_user.iam_user.*.name[count.index]}"]
  roles      = []
  depends_on = ["aws_iam_user.iam_user", "aws_iam_policy.get_user_policy"]
}

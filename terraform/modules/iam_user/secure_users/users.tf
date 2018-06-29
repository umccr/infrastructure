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

resource "aws_iam_policy" "get_user_policy" {
  name        = "${aws_iam_user.iam_user.*.name[count.index]}_user_policy"
  description = "Default permissions granted to every user."
  count       = "${length(keys(var.users))}"
  path        = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "iam:GetUser",
                "iam:ListMFADevices",
                "iam:ChangePassword"
            ],
            "Resource": "${aws_iam_user.iam_user.*.arn[count.index]}"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "iam:GetAccountPasswordPolicy"
            ],
            "Resource": "*"
        }
    ]
}
EOF
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

################################################################################
# AWS Backup configuration for Aurora DB

data "aws_kms_key" "backup" {
  key_id = "alias/aws/backup"
}

resource "aws_iam_role" "db_backup_role" {
  count              = var.create_aws_backup[terraform.workspace]
  name               = "${local.stack_name_us}_backup_role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["backup.amazonaws.com"]
      }
    }
  ]
}
POLICY

  tags = merge(local.default_tags)
}

resource "aws_iam_role_policy_attachment" "db_backup_role_policy" {
  count      = var.create_aws_backup[terraform.workspace]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.db_backup_role[count.index].name
}

resource "aws_iam_role_policy_attachment" "db_backup_role_restore_policy" {
  count      = var.create_aws_backup[terraform.workspace]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.db_backup_role[count.index].name
}

resource "aws_backup_vault" "db_backup_vault" {
  count = var.create_aws_backup[terraform.workspace]
  name  = "${local.stack_name_us}_backup_vault"
  kms_key_arn = data.aws_kms_key.backup.arn
  tags  = merge(local.default_tags)
}

resource "aws_backup_plan" "db_backup_plan" {
  count = var.create_aws_backup[terraform.workspace]
  name  = "${local.stack_name_us}_backup_plan"

  // Backup weekly and keep it for 6 weeks
  // Cron At 17:00 on every Sunday UTC = AEST/AEDT 3AM/4AM on every Monday
  rule {
    rule_name         = "Weekly"
    target_vault_name = aws_backup_vault.db_backup_vault[count.index].name
    schedule          = "cron(0 17 ? * SUN *)"

    lifecycle {
      delete_after = 42
    }
  }

  tags = merge(local.default_tags)
}

resource "aws_backup_selection" "db_backup" {
  count        = var.create_aws_backup[terraform.workspace]
  name         = "${local.stack_name_us}_backup"
  plan_id      = aws_backup_plan.db_backup_plan[count.index].id
  iam_role_arn = aws_iam_role.db_backup_role[count.index].arn

  resources = [
    aws_rds_cluster.db.arn,
  ]
}

/**
 * Secret for storing Seqera API details for sharing across accounts for terraforming.
 *
 * Research accounts need a powerful API token from seqera in order to create
 * workspaces and compute environments. The user of the token should be a service
 * user so that workspaces do not need to be removed when staff move.
 *
 * We store here an API token and server URL for Seqera biocommons such
 * that it can be used by downstream accounts as part of provisioning
 * their terraform seqera provider.
 */

locals {
  secret_name        = "seqera-biocommons"
  secret_description = "for use in terraforming Seqera research projects"
}

resource "aws_secretsmanager_secret" "seqera_secret" {
  name        = local.secret_name
  description = "Cross account shared secret ${local.secret_description}"

  # for cross account secrets it is a requirement to use a custom KMS
  kms_key_id = aws_kms_key.seqera_secret.arn
}

resource "aws_secretsmanager_secret_version" "seqera_secret" {
  secret_id = aws_secretsmanager_secret.seqera_secret.id

  secret_string = jsonencode({
    # will need to be set once out of band of this terraform
    apiToken  = "REPLACEME"
    serverUrl = "REPLACEME"
  })
}

resource "aws_secretsmanager_secret_policy" "seqera_secret" {
  secret_arn = aws_secretsmanager_secret.seqera_secret.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountGetSecretValue"
        Effect = "Allow"
        Principal = {
          AWS = [for a in local.account_id_list_without_management_account : "arn:aws:iam::${a}:root"]
        }
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
        # note that we also restrict the principal to our account list - we don't *just*
        # rely on this condition
        Condition = {
          StringLike = {
            "aws:PrincipalArn" : local.terraform_allowed_roles
          }
        }
      }
    ]
  })
}

resource "aws_kms_key" "seqera_secret" {
  description             = "KMS key for secrets manager ${local.secret_description}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # allow the owning account full control
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # allow the consuming accounts to decrypt only
      # note that this is broader than the corresponding GetSecretValue policy, but both
      # the secret policy *and* the KMS policy need to be satisfied to actually get the secret value
      {
        Sid    = "AllowCrossAccountDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = [for a in local.account_id_list_without_management_account : "arn:aws:iam::${a}:root"]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

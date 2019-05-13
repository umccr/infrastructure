variable "stack_name" {
  default = "bastion"
}

variable "slack_channel" {
  default = "#biobots"
}

################################################################################
# NOTE: The following is currently NOT used. This showe the config if the
#       "secure_users" module would be used.
################################################################################

################################################################################
# define users with console login
variable "console_users" {
  type        = "map"
  description = "Map of user names (key) to their PGP key/keybase id (value) for users with console login."

  default = {
    florian    = "keybase:freisinger"
    brainstorm = "keybase:brainstorm"
    oliver     = "keybase:ohofmann"
    vlad       = "keybase:vladsaveliev"
  }
}

# define service users (without console login)
variable "service_users" {
  type        = "map"
  description = "Map of service user names (key) to their PGP key/keybase id (value)."

  # TODO: replace personal keybase ID with umccr account that multiple people have access to
  default = {
    packer         = "keybase:freisinger"
    terraform      = "keybase:freisinger"
    sample_monitor = "keybase:freisinger"
  }
}

################################################################################
# define user groups and memberships
variable "group_memberships" {
  type = "map"

  default = {
    ops_admins_prod             = ["florian", "brainstorm", "nrclark"]
    ops_admins_dev              = ["florian", "brainstorm", "vlad", "nrclark"]
    packer_users                = ["florian", "brainstorm", "nrclark", "packer"]
    ops_admins_dev_no_mfa_users = ["florian", "brainstorm", "nrclark", "vlad", "oliver", "terraform"]
    fastq_data_uploaders        = ["florian", "brainstorm", "nrclark", "vlad", "oliver", "terraform"]
  }
}

################################################################################
# define which groups are allowed to assume which roles with/without MFA
variable "roles_with_mfa" {
  type = "map"

  default = {
    ops_admins_prod = ["arn:aws:iam::472057503814:role/ops-admin"]
    ops_admins_dev  = ["arn:aws:iam::620123204273:role/ops-admin"]
  }
}

variable "roles_without_mfa" {
  type = "map"

  default = {
    ops_admins_dev_no_mfa_users = ["arn:aws:iam::620123204273:role/ops_admin_no_mfa"]
    packer_users                = ["arn:aws:iam::620123204273:role/packer_role"]
    fastq_data_uploaders        = ["arn:aws:iam::472057503814:role/fastq_data_uploader", "arn:aws:iam::620123204273:role/fastq_data_uploader"]
  }
}

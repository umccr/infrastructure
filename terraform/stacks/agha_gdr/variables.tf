################################################################################
# workspace specific variables
# NOTE: only 'dev' is supported at this stage
variable "workspace_name_suffix" {
  default = {
    prod = "_prod"
    dev  = "_dev"
  }
}

variable "agha_gdr_staging_bucket_name" {
  default = {
    prod = "agha-gdr-staging-prod"
    dev  = "agha-gdr-staging-dev"
  }
}

variable "agha_gdr_store_bucket_name" {
  default = {
    prod = "agha-gdr-store-prod"
    dev  = "agha-gdr-store-dev"
  }
}

variable "agha_gdr_log_bucket_name" {
  default = {
    prod = "agha-gdr-log-prod"
    dev  = "agha-gdr-log-dev"
  }
}

################################################################################
# define (AGHA specific) users
variable "agha_users_map" {
  type        = "map"
  description = "Map of user names (key) to their PGP key/keybase id (value) for users with console login."

  default = {
    ametke       = "keybase:ametke"
    simonsadedin = "keybase:simonsadedin"
    sebastian    = "keybase:freisinger"
    ebenngarvan  = "keybase:ebenngarvan"
  }
}

variable "group_members_map" {
  type        = "map"
  description = "Map groups to their members."

  default = {
    agha_gdr_admins = ["reisingerf"]
    agha_gdr_submit = ["simonsadedin", "sebastian"]
    agha_gdr_read   = ["ametke", "ebenngarvan"]
  }
}

# each group gets its own role
variable "group_roles_map" {
  type        = "map"
  description = "Map of groups to their role(s)."

  # Used to create the roles (one for each group) and associate the group with the role

  default = {
    agha_gdr_admins = ["arn:aws:iam::620123204273:role/agha_gdr_admins"]
    agha_gdr_submit = ["arn:aws:iam::620123204273:role/agha_gdr_submit"]
    agha_gdr_read   = ["arn:aws:iam::620123204273:role/agha_gdr_read"]
  }
}

# define which roles get which access policies
# there are currently three policies
variable "agha_staging_rw" {
  type        = "list"
  description = "List of roles that have r/w access to the AGHA staging bucket (submitters)."

  default = [
    "agha_gdr_admins",
    "agha_gdr_submit",
  ]
}

variable "agha_store_ro" {
  type        = "list"
  description = "List of roles that have r/o access to the AGHA store bucket (end-users/consumers)."

  default = [
    "agha_gdr_read",
    "agha_gdr_submit",
  ]
}

variable "agha_store_rw" {
  type        = "list"
  description = "List of roles that have r/w access to the AGHA store bucket (admins)."

  default = [
    "agha_gdr_admins",
  ]
}

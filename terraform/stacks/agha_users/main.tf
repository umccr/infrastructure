terraform {
  required_version = ">= 0.12.6"

  backend "s3" {
    bucket         = "agha-terraform-states"
    key            = "agha_users/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  common_tags = {
    "Environment": "agha",
    "Stack": var.stack_name
  }
}

################################################################################
# S3 buckets

data "aws_s3_bucket" "agha_gdr_staging" {
  bucket = var.agha_gdr_staging_bucket_name
}

data "aws_s3_bucket" "agha_gdr_store" {
  bucket = var.agha_gdr_store_bucket_name
}


################################################################################
# Users

# # Dedicated user to generate long lived presigned URLs
# # See: https://aws.amazon.com/premiumsupport/knowledge-center/presigned-url-s3-bucket-expiration/
module "agha_presign" {
  source    = "../../modules/iam_user/default_user"
  username  = "agha_presign"
  pgp_key   = "keybase:freisinger"
}

#####
# Dedicated user for Gen3 (fence_bot)
resource "aws_iam_user" "fence_bot" {
  name = "fence_bot"
  path = "/gen3/"
  tags = {
    name    = "fence_bot"
  }
}


# AGHA Users
module "simon" {
  source    = "../../modules/iam_user/only_user"
  username  = "simon"
  full_name = "Simon Sadedin"
  keybase   = "simonsadedin"
  email     = "simon.sadedin@vcgs.org.au"
}

# resource "aws_iam_user" "shyrav" {
#   name = "shyrav"
#   path = "/agha/"
#   force_destroy = true
#   tags = {
#     email   = "s.ravishankar@garvan.org.au",
#     name    = "Shyamsundar Ravishankar",
#     keybase = "shyrav"
#   }
# }
resource "aws_iam_user" "shyrav_consent" {
  name = "shyrav_consent"
  path = "/agha/"
  force_destroy = true
  tags = {
    email   = "s.ravishankar@garvan.org.au",
    name    = "Shyamsundar Ravishankar",
    keybase = "shyrav"
  }
}

resource "aws_iam_user" "thangu_consent" {
  name = "thangu_consent"
  path = "/agha/"
  force_destroy = true
  tags = {
    email   = "thanh.nguyen@garvan.org.au",
    name    = "Thanh Nguyen",
    keybase = "thangu"
  }
}
# resource "aws_iam_user" "yingzhu" {
#   name = "yingzhu"
#   path = "/agha/"
#   force_destroy = true
#   tags = {
#     email   = "Ying.Zhu@health.nsw.gov.au",
#     name    = "Ying Zhu",
#     keybase = "yingzhu"
#   }
# }

# resource "aws_iam_user" "seanlianu" {
#   name = "seanlianu"
#   path = "/agha/"
#   force_destroy = true
#   tags = {
#     email   = "sean.li@anu.edu.au",
#     name    = "Sean Li",
#     keybase = "seanlianu"
#   }
# }

# resource "aws_iam_user" "chiaraf" {
#   name = "chiaraf"
#   path = "/agha/"
#   force_destroy = true
#   tags = {
#     email   = "22253832@student.uwa.edu.au",
#     name    = "Chiara Folland",
#     keybase = "chiaraf"
#   }
# }

# resource "aws_iam_user" "qimrbscott" {
#   name = "qimrbscott"
#   path = "/agha/"
#   force_destroy = true
#   tags = {
#     email   = "Scott.Wood@qimrberghofer.edu.au",
#     name    = "Scott Wood",
#     keybase = "qimrbscott"
#   }
# }

# Mackenzie's Mission
# resource "aws_iam_user" "fzhanghealth" {
#   name = "fzhanghealth"
#   path = "/agha/"
#   force_destroy = true
#   tags = {
#     email   = "futao.zhang@health.nsw.gov.au",
#     name    = "Futao Zhang",
#     keybase = "fzhanghealth"
#   }
# }

resource "aws_iam_user" "evachan" {
  name = "evachan"
  path = "/agha/"
  force_destroy = true
  tags = {
    email   = "eva.chan@health.nsw.gov.au",
    name    = "Eva Chan",
    keybase = "evachan"
  }
}

resource "aws_iam_user" "ohofmann" {
  name = "ohofmann"
  path = "/agha/"
  tags = {
    email   = "ohofmann72@gmail.com",
    name    = "Oliver Hofmann",
    keybase = "ohofmann"
  }
}

# Data Manager/Controller
module "sarah_dm" {
  source    = "../../modules/iam_user/default_user"
  username  = "sarah_dm"
  full_name = "Sarah Casauria"
  keybase   = "scasauria"
  pgp_key   = "keybase:freisinger"
  email     = "sarah.casauria@mcri.edu.au"
}
resource "aws_iam_user_login_profile" "sarah_dm" {
  user    = module.sarah_dm.username
  pgp_key = "keybase:freisinger"
}

################################################################################
# Groups

# Default
resource "aws_iam_group" "default" {
  name = "agha_gdr_default"
  path = "/agha/"
}

# Submitters
resource "aws_iam_group" "submitter" {
  name = "agha_gdr_submitters"
  path = "/agha/"
}

# Consumers
resource "aws_iam_group" "consumer" {
  name = "agha_gdr_consumers"
  path = "/agha/"
}

# Data Controllers
resource "aws_iam_group" "data_controller" {
  name = "agha_gdr_controller"
  path = "/agha/"
}

# Gen3
resource "aws_iam_group" "gen3" {
  name = "agha_gdr_gen3"
  path = "/gen3/"
}

####################
# Group memberships

# Default
resource "aws_iam_group_membership" "default" {
  name  = "${aws_iam_group.default.name}_membership"
  group = aws_iam_group.default.name
  users = [
    module.sarah_dm.username,
    module.simon.username,
    # module.shyrav.username,
    # module.yingzhu.username,
    # module.seanlianu.username,
    # module.chiaraf.username,
    # module.qimrbscott.username,
    # aws_iam_user.fzhanghealth.name,
    aws_iam_user.evachan.name,
    aws_iam_user.shyrav_consent.name,
    aws_iam_user.thangu_consent.name,
  ]
}

resource "aws_iam_group_policy_attachment" "default_user_policy_attachment" {
  group      = aws_iam_group.default.name
  policy_arn = aws_iam_policy.default_user_policy.arn
}

# Submitters
resource "aws_iam_group_membership" "submitter" {
  name  = "${aws_iam_group.submitter.name}_membership"
  group = aws_iam_group.submitter.name
  users = [
    module.agha_presign.username,
    module.sarah_dm.username,
    module.simon.username,
    # module.yingzhu.username,
    # module.seanlianu.username,
    # module.chiaraf.username,
    # module.qimrbscott.username,
  ]
}

resource "aws_iam_group_policy_attachment" "submit_staging_rw_policy_attachment" {
  group      = aws_iam_group.submitter.name
  policy_arn = aws_iam_policy.agha_staging_rw_policy.arn
}

resource "aws_iam_group_policy_attachment" "submit_store_ro_policy_attachment" {
  group      = aws_iam_group.submitter.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}

# Consumers
resource "aws_iam_group_membership" "consumer" {
  name  = "${aws_iam_group.consumer.name}_membership"
  group = aws_iam_group.consumer.name
  users = [
    # module.shyrav.username
  ]
}

resource "aws_iam_group_policy_attachment" "consumer_store_ro_policy_attachment" {
  group      = aws_iam_group.consumer.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}

# Controllers
resource "aws_iam_group_membership" "data_controller" {
  name  = "${aws_iam_group.data_controller.name}_membership"
  group = aws_iam_group.data_controller.name
  users = [
    module.sarah_dm.username
  ]
}

resource "aws_iam_group_policy_attachment" "controller_additional_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.data_controller_policy.arn
}

resource "aws_iam_group_policy_attachment" "controller_staging_ro_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.agha_staging_ro_policy.arn
}

resource "aws_iam_group_policy_attachment" "controller_store_ro_policy_attachment" {
  group      = aws_iam_group.data_controller.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}

# Gen3 services
resource "aws_iam_group_membership" "gen3_services" {
  name  = "${aws_iam_group.gen3.name}_membership"
  group = aws_iam_group.gen3.name
  users = [
    aws_iam_user.fence_bot.name
  ]
}

resource "aws_iam_group_policy_attachment" "gen3_services_store_ro_policy_attachment" {
  group      = aws_iam_group.gen3.name
  policy_arn = aws_iam_policy.agha_store_ro_policy.arn
}

################################################################################
# Create access policies

data "template_file" "agha_staging_ro_policy" {
  template = file("policies/bucket-ro-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_staging.id
  }
}

data "template_file" "agha_staging_rw_policy" {
  template = file("policies/bucket-rw-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_staging.id
  }
}

data "template_file" "agha_store_ro_policy" {
  template = file("policies/bucket-ro-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_store.id
  }
}

resource "aws_iam_policy" "default_user_policy" {
  name_prefix = "default_user_policy"
  path        = "/agha/"
  policy = file("policies/default-user-policy.json")
}

resource "aws_iam_policy" "data_controller_policy" {
  name_prefix = "data_controller_policy"
  path        = "/agha/"
  policy = file("policies/data-controller-policy.json")
}

resource "aws_iam_policy" "agha_staging_ro_policy" {
  name_prefix = "agha_staging_ro_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_staging_ro_policy.rendered
}

resource "aws_iam_policy" "agha_staging_rw_policy" {
  name_prefix = "agha_staging_rw_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_staging_rw_policy.rendered
}

resource "aws_iam_policy" "agha_store_ro_policy" {
  name_prefix = "agha_store_ro_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_store_ro_policy.rendered
}

################################################################################

## Consented data access test

data "template_file" "abac_store_policy" {
  template = file("policies/bucket-ro-abac-s3-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_store.id,
    consent_group = "True"
  }
}

resource "aws_iam_policy" "abac_store_policy" {
  name_prefix = "agha_store_abac_policy"
  path        = "/agha/"
  policy      = data.template_file.abac_store_policy.rendered
}

data "template_file" "abac_staging_policy" {
  template = file("policies/bucket-ro-abac-s3-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_staging.id,
    consent_group = "True"
  }
}

resource "aws_iam_policy" "abac_staging_policy" {
  name_prefix = "agha_store_abac_policy"
  path        = "/agha/"
  policy      = data.template_file.abac_staging_policy.rendered
}

resource "aws_iam_user" "abac" {
  name = "abac"
  path = "/agha/"
  tags = {
    name    = "ABAC Test",
    keybase = "abac"
  }
}

# group
resource "aws_iam_group" "abac" {
  name = "agha_gdr_abac"
  path = "/agha/"
}

# group membership
resource "aws_iam_group_membership" "abac" {
  name  = "${aws_iam_group.abac.name}_membership"
  group = aws_iam_group.abac.name
  users = [
    aws_iam_user.abac.name,
    aws_iam_user.ohofmann.name,
    aws_iam_user.shyrav_consent.name,
    aws_iam_user.thangu_consent.name,
  ]
}

# group policies
resource "aws_iam_group_policy_attachment" "abac_store_policy_attachment" {
  group      = aws_iam_group.abac.name
  policy_arn = aws_iam_policy.abac_store_policy.arn
}
resource "aws_iam_group_policy_attachment" "abac_staging_policy_attachment" {
  group      = aws_iam_group.abac.name
  policy_arn = aws_iam_policy.abac_staging_policy.arn
}

################################################################################

## Mackenzie's Mission

# bucket
data "aws_s3_bucket" "agha_gdr_mm" {
  bucket = var.agha_gdr_mm_bucket_name
}

# group
resource "aws_iam_group" "mm" {
  name = "agha_gdr_mm"
  path = "/agha/"
}

# group membership
resource "aws_iam_group_membership" "mm" {
  name  = "${aws_iam_group.mm.name}_membership"
  group = aws_iam_group.mm.name
  users = [
    module.sarah_dm.username,
    # aws_iam_user.fzhanghealth.name,
    aws_iam_user.evachan.name,
  ]
}

# group policies
resource "aws_iam_group_policy_attachment" "mm_mm_rw_policy_attachment" {
  group      = aws_iam_group.mm.name
  policy_arn = aws_iam_policy.agha_mm_rw_policy.arn
}

# policy
data "template_file" "agha_mm_rw_policy" {
  template = file("policies/bucket-rw-policy.json")

  vars = {
    bucket_name = data.aws_s3_bucket.agha_gdr_mm.id
  }
}

resource "aws_iam_policy" "agha_mm_rw_policy" {
  name_prefix = "agha_mm_rw_policy"
  path        = "/agha/"
  policy      = data.template_file.agha_mm_rw_policy.rendered
}

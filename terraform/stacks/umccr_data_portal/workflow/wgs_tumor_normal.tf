locals {
  wgs_tumor_normal_wfl_id = {
    dev  = "wfl.a4056543ef9a474d8b16182a4e6b6c50"
    prod = "wfl.5830565f0858423cb49de2a1534d65c5"
    stg  = "wfl.5830565f0858423cb49de2a1534d65c5"
  }

  wgs_tumor_normal_wfl_version = {
    dev  = "4.2.4"
    prod = "4.2.4--0fab721"
    stg  = "4.2.4--0fab721"
  }

  wgs_tumor_normal_wfl_input = {
    dev  = file("${path.module}/template/wgs_tumor_normal_dev.json")
    prod = file("${path.module}/template/wgs_tumor_normal_prod.json")
    stg  = file("${path.module}/template/wgs_tumor_normal_stg.json")
  }
}

# --- Tumor / Normal

resource "aws_ssm_parameter" "wgs_tumor_normal_wfl_id" {
  name        = "/iap/workflow/wgs_tumor_normal/id"
  type        = "String"
  description = "Tumor / Normal Workflow ID"
  value       = local.wgs_tumor_normal_wfl_id[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wgs_tumor_normal_wfl_version" {
  name        = "/iap/workflow/wgs_tumor_normal/version"
  type        = "String"
  description = "Tumor / Normal Workflow Version Name"
  value       = local.wgs_tumor_normal_wfl_version[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wgs_tumor_normal_wfl_input" {
  name        = "/iap/workflow/wgs_tumor_normal/input"
  type        = "String"
  description = "Tumor / Normal Input JSON"
  value       = local.wgs_tumor_normal_wfl_input[terraform.workspace]
  tags        = merge(local.default_tags)
}

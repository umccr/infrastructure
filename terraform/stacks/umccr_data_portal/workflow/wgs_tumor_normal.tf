locals {
  wgs_tumor_normal_wfl_id = {
    dev  = "wfl.32e346cdbb854f6487e7594ec17a81f9"
    prod = "wfl.aa0ccece4e004839aa7374d1d6530633"
    stg  = "wfl.aa0ccece4e004839aa7374d1d6530633"
  }

  wgs_tumor_normal_wfl_version = {
    dev  = "3.9.3"
    prod = "3.9.3--4e00721"
    stg  = "3.9.3--4e00721"
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

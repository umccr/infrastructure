locals {
  umccrise_wfl_id = {
    dev  = "wfl.af61d2b172e84cbfa85eaf184226db8b"
    prod = "wfl.714e9172f3674023b210ccc7c47db05a"
    stg  = "wfl.714e9172f3674023b210ccc7c47db05a"
  }

  umccrise_wfl_version = {
    dev  = "2.3.0--0"
    prod = "2.2.0--0--3fc7b5e"
    stg  = "2.2.0--0--3fc7b5e"
  }

  umccrise_wfl_input = {
    dev  = file("${path.module}/template/umccrise_dev.json")
    prod = file("${path.module}/template/umccrise_prod.json")
    stg  = file("${path.module}/template/umccrise_stg.json")
  }
}

# --- UMCCRISE for post-processing WGS samples

resource "aws_ssm_parameter" "umccrise_wfl_id" {
  name        = "/iap/workflow/umccrise/id"
  type        = "String"
  description = "UMCCRise Workflow ID"
  value       = local.umccrise_wfl_id[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "umccrise_wfl_version" {
  name        = "/iap/workflow/umccrise/version"
  type        = "String"
  description = "UMCCRise Workflow Version Name"
  value       = local.umccrise_wfl_version[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "umccrise_wfl_input" {
  name        = "/iap/workflow/umccrise/input"
  type        = "String"
  description = "UMCCRise Input JSON"
  value       = local.umccrise_wfl_input[terraform.workspace]
  tags        = merge(local.default_tags)
}

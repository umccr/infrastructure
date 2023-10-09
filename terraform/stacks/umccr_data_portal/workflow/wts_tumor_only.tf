locals {
  wts_tumor_only_wfl_id = {
    dev  = "wfl.286d4a2e82f048609d5b288a9d2868f6"
    prod = "wfl.7e5ba7470b5549a6b4bf6d95daaa1214"
    stg  = "wfl.7e5ba7470b5549a6b4bf6d95daaa1214"
  }

  wts_tumor_only_wfl_version = {
    dev  = "4.2.4"
    prod = "3.9.3--8fdabfc"
    stg  = "4.2.4--4b01ed3"
  }

  wts_tumor_only_wfl_input = {
    dev  = file("${path.module}/template/wts_tumor_only_dev.json")
    prod = file("${path.module}/template/wts_tumor_only_prod.json")
    stg  = file("${path.module}/template/wts_tumor_only_stg.json")
  }
}

# --- DRAGEN WTS Workflow for Transcriptome samples

resource "aws_ssm_parameter" "wts_tumor_only_wfl_id" {
  name        = "/iap/workflow/wts_tumor_only/id"
  type        = "String"
  description = "DRAGEN WTS Workflow ID"
  value       = local.wts_tumor_only_wfl_id[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wts_tumor_only_wfl_version" {
  name        = "/iap/workflow/wts_tumor_only/version"
  type        = "String"
  description = "DRAGEN WTS Workflow Version Name"
  value       = local.wts_tumor_only_wfl_version[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wts_tumor_only_wfl_input" {
  name        = "/iap/workflow/wts_tumor_only/input"
  type        = "String"
  description = "DRAGEN WTS Input JSON"
  value       = local.wts_tumor_only_wfl_input[terraform.workspace]
  tags        = merge(local.default_tags)
}

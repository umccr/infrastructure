locals {
  tso_ctdna_tumor_only_wfl_id = {
    dev  = "wfl.b0be3d1bbd8140bbaa64038f0eb8f7c2"
    prod = "wfl.230846758ccf42e3831283ab0e45af0a"
    stg  = "wfl.230846758ccf42e3831283ab0e45af0a"
  }

  tso_ctdna_tumor_only_wfl_version = {
    dev  = "1.2.0--1.0.0"
    prod = "1.2.0--1.0.0--e2eeccc"
    stg  = "1.2.0--1.0.0--6753613"
  }

  tso_ctdna_tumor_only_wfl_input = {
    dev  = file("${path.module}/template/tso_ctdna_tumor_only_dev.json")
    prod = file("${path.module}/template/tso_ctdna_tumor_only_prod.json")
    stg  = file("${path.module}/template/tso_ctdna_tumor_only_stg.json")
  }
}

# --- DRAGEN_TSO_CTDNA

resource "aws_ssm_parameter" "tso_ctdna_tumor_only_wfl_id" {
  name        = "/iap/workflow/tso_ctdna_tumor_only/id"
  type        = "String"
  description = "Dragen ctTSO Workflow ID"
  value       = local.tso_ctdna_tumor_only_wfl_id[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "tso_ctdna_tumor_only_wfl_version" {
  name        = "/iap/workflow/tso_ctdna_tumor_only/version"
  type        = "String"
  description = "Dragen ctTSO Workflow Version Name"
  value       = local.tso_ctdna_tumor_only_wfl_version[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "tso_ctdna_tumor_only_wfl_input" {
  name        = "/iap/workflow/tso_ctdna_tumor_only/input"
  type        = "String"
  description = "Dragen ctTSO Input JSON"
  value       = local.tso_ctdna_tumor_only_wfl_input[terraform.workspace]
  tags        = merge(local.default_tags)
}

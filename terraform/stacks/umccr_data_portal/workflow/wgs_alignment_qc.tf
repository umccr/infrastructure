locals {
  wgs_alignment_qc_wfl_id = {
    dev  = "wfl.ff6ca1789f4e4eb0982ea3e01407aca8"
    prod = "wfl.23f61cb1baab412a8c37dc93bed6c2af"
    stg  = "wfl.c07ecc424a5a41bd94abe9ef519867a0"
  }

  wgs_alignment_qc_wfl_version = {
    dev  = "3.9.3"
    prod = "3.9.3--4e00721"
    stg  = "4.2.4--5bfabd0"
  }

  wgs_alignment_qc_wfl_input = {
    dev  = file("${path.module}/template/wgs_alignment_qc_dev.json")
    prod = file("${path.module}/template/wgs_alignment_qc_prod.json")
    stg  = file("${path.module}/template/wgs_alignment_qc_stg.json")
  }
}

# --- DRAGEN WGS QC Workflow for WGS samples (used to call Germline initially)

resource "aws_ssm_parameter" "wgs_alignment_qc_wfl_id" {
  name        = "/iap/workflow/wgs_alignment_qc/id"
  type        = "String"
  description = "DRAGEN_WGS_QC Workflow ID"
  value       = local.wgs_alignment_qc_wfl_id[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wgs_alignment_qc_wfl_version" {
  name        = "/iap/workflow/wgs_alignment_qc/version"
  type        = "String"
  description = "DRAGEN_WGS_QC Workflow Version Name"
  value       = local.wgs_alignment_qc_wfl_version[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wgs_alignment_qc_wfl_input" {
  name        = "/iap/workflow/wgs_alignment_qc/input"
  type        = "String"
  description = "DRAGEN_WGS_QC Input JSON"
  value       = local.wgs_alignment_qc_wfl_input[terraform.workspace]
  tags        = merge(local.default_tags)
}

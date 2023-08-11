locals {
  wgs_alignment_qc_wfl_id = {
    dev  = "wfl.a3e19e590ed34a0fa0518718cb8a36cf"
    prod = "wfl.c07ecc424a5a41bd94abe9ef519867a0"
    stg  = "wfl.c07ecc424a5a41bd94abe9ef519867a0"
  }

  wgs_alignment_qc_wfl_version = {
    dev  = "4.2.4"
    prod = "4.2.4--5bfabd0"
    stg  = "4.2.4--5bfabd0"
  }

  wgs_alignment_qc_wfl_input = {
    dev  = file("${path.module}/template/wgs_alignment_qc_dev.json")
    prod = file("${path.module}/template/wgs_alignment_qc_prod.json")
    stg  = file("${path.module}/template/wgs_alignment_qc_stg.json")
  }
}

# --- DRAGEN WGS QC Workflow for WGS samples

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

# --- DRAGEN WTS QC Workflow for WTS samples
# For now, DRAGEN_WGS_QC and DRAGEN_WTS_QC workflows point to the same workflow at ICA CWL side.
# See below:
# https://github.com/umccr/data-portal-apis/pull/611
# https://github.com/umccr/infrastructure/pull/334

resource "aws_ssm_parameter" "wts_alignment_qc_wfl_id" {
  name        = "/iap/workflow/wts_alignment_qc/id"
  type        = "String"
  description = "DRAGEN_WTS_QC Workflow ID"
  value       = local.wgs_alignment_qc_wfl_id[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wts_alignment_qc_wfl_version" {
  name        = "/iap/workflow/wts_alignment_qc/version"
  type        = "String"
  description = "DRAGEN_WTS_QC Workflow Version Name"
  value       = local.wgs_alignment_qc_wfl_version[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wts_alignment_qc_wfl_input" {
  name        = "/iap/workflow/wts_alignment_qc/input"
  type        = "String"
  description = "DRAGEN_WTS_QC Input JSON"
  value       = local.wgs_alignment_qc_wfl_input[terraform.workspace]
  tags        = merge(local.default_tags)
}

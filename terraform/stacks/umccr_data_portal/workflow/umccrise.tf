locals {
  umccrise_wfl_id = {
    dev  = "wfl.e4cd73b0e6e941b3b48afe03a7b5dc43"
    prod = "wfl.7ed9c6014ac9498fbcbd4c17c28bc0d4"
    stg  = "wfl.7ed9c6014ac9498fbcbd4c17c28bc0d4"
  }

  umccrise_wfl_version = {
    dev  = "2.2.0--3.9.3"
    prod = "2.2.0--3.9.3--4e00721"
    stg  = "2.2.0--3.9.3--4e00721"
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

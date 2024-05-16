locals {
  rnasum_wfl_id = {
    dev  = "wfl.a94ae5ef8bc24b58b642cc8e42df70a4"
    prod = "wfl.87e07ae6b46645a181e04813de535216"
    stg  = "wfl.87e07ae6b46645a181e04813de535216"
  }

  rnasum_wfl_version = {
    dev  = "0.6.5"
    prod = "0.6.5--6f2b117"
    stg  = "0.4.9--3694eb2"
  }

  rnasum_wfl_input = {
    dev  = file("${path.module}/template/rnasum_dev.json")
    prod = file("${path.module}/template/rnasum_prod.json")
    stg  = file("${path.module}/template/rnasum_stg.json")
  }
}

# --- RNAsum for postprocessing WTS samples

resource "aws_ssm_parameter" "rnasum_wfl_id" {
  name        = "/iap/workflow/rnasum/id"
  type        = "String"
  description = "RNAsum Workflow ID"
  value       = local.rnasum_wfl_id[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "rnasum_wfl_version" {
  name        = "/iap/workflow/rnasum/version"
  type        = "String"
  description = "RNAsum Workflow Version Name"
  value       = local.rnasum_wfl_version[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "rnasum_wfl_input" {
  name        = "/iap/workflow/rnasum/input"
  type        = "String"
  description = "RNAsum Input JSON"
  value       = local.rnasum_wfl_input[terraform.workspace]
  tags        = merge(local.default_tags)
}

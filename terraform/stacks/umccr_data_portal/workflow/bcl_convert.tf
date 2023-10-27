locals {
  bcl_convert_wfl_id = {
    dev  = "wfl.f257ca35ced94e648fdda1173144c476"
    prod = "wfl.f257ca35ced94e648fdda1173144c476"
    stg  = "wfl.f257ca35ced94e648fdda1173144c476"
  }

  bcl_convert_wfl_version = {
    dev  = "3.7.5--6eacfb8"
    prod = "3.7.5--0bac6d0"
    stg  = "3.7.5--6eacfb8"
  }

  bcl_convert_wfl_input = {
    dev  = file("${path.module}/template/bcl_convert_dev.json")
    prod = file("${path.module}/template/bcl_convert_prod.json")
    stg  = file("${path.module}/template/bcl_convert_stg.json")
  }
}

# --- BCL Convert

resource "aws_ssm_parameter" "bcl_convert_id" {
  name        = "/iap/workflow/bcl_convert/id"
  type        = "String"
  description = "BCL Convert Workflow ID"
  value       = local.bcl_convert_wfl_id[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "bcl_convert_version" {
  name        = "/iap/workflow/bcl_convert/version"
  type        = "String"
  description = "BCL Convert Workflow Version Name"
  value       = local.bcl_convert_wfl_version[terraform.workspace]
  tags        = merge(local.default_tags)
}

resource "aws_ssm_parameter" "bcl_convert_input" {
  name        = "/iap/workflow/bcl_convert/input"
  type        = "String"
  description = "BCL Convert Workflow Input JSON"
  value       = local.bcl_convert_wfl_input[terraform.workspace]
  tags        = merge(local.default_tags)
}

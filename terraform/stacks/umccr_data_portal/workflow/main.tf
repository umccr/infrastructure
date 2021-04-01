terraform {
  required_version = ">= 0.14"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_portal_workflow_automation/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "~> 3.26.0"
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  token_desc = {
    dev  = "IAP Token using development workgroup"
    prod = "IAP Token using production workgroup"
  }

  token_tier = {
    # Standard -- 4096 characters limit
    # Advanced -- $0.05 per advanced parameter per month (prorated hourly if the parameter is stored less than a month)
    dev  = "Advanced"
    prod = "Advanced"
  }

  bcl_convert_wfl_id = {
    dev  = "wfl.84abc203cabd4dc196a6cf9bb49d5f74"
    prod = "wfl.1f705d91294440d4bc6d36386d12a372"
  }

  bcl_convert_wfl_version = {
    dev  = "1.0.7"
    prod = "1.0.7-75d4446"
  }

  bcl_convert_input = {
    dev = <<-EOT
    {
      "bcl_input_directory": {
        "class": "Directory",
        "location": "PLACEHOLDER"
      }
      "samplesheet": {
        "class": "File",
        "location": "PLACEHOLDER"
      },
      "settings_by_samples": [],
      "samplesheet_outdir": "samplesheets-by-assay-type",
      "ignore_missing_samples": true,
      "samplesheet_output_format": "v2",
      "bcl_sampleproject_subdirectories_bcl_conversion": true,
      "strict_mode_bcl_conversion": true,
      "delete_undetermined_indices_bcl_conversion": true,
      "runfolder_name": "PLACEHOLDER",
    }
    EOT
    prod = <<-EOT
    {
      "v2-out-split-by-override-cycles": true,
      "strict-mode-bcl-conversion": true,
      "samplesheet": {
        "class": "File",
        "location": "PLACEHOLDER"
      },
      "samples": [
        "PLACEHOLDER_1",
        "PLACEHOLDER_2"
      ],
      "override-cycles": [
        "PLACEHOLDER_3",
        "PLACEHOLDER_4"
      ],
      "runfolder-name": "PLACEHOLDER",
      "outdir-split-by-override-cycles": "samplesheets-by-override-cycles",
      "module-multiqc": "interop",
      "ignore-missing-samples-split-by-override-cycles": true,
      "dummyFile-multiqc": {
        "class": "File",
        "location": "PLACEHOLDER"
      },
      "delete-undetermined-bcl-conversions": true,
      "bcl-sample-project-subdirectories-bcl-conversion": true,
      "bcl-input-directory": {
        "class": "Directory",
        "location": "PLACEHOLDER"
      }
    }
    EOT
  }

  germline_wfl_id = {
    dev  = "wfl.5cc28c147e4e4dfa9e418523188aacec"
    prod = "wfl.d6f51b67de5b4d309dddf4e411362be7"
  }

  germline_wfl_version = {
    dev  = "0.2-inputcsv-redir"
    prod = "0.2-inputcsv-redir-8277438"
  }

  germline_input = {
    dev = <<-EOT
    {
      "sample-name": "PLACEHOLDER",
      "fastq-directory": {
        "class": "Directory",
        "location": "PLACEHOLDER"
      },
      "fastq-list": {
        "class": "File",
        "location": "PLACEHOLDER"
      },
      "refdata-dragen": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/dragen/hsapiens/hg38/3.5.2_ht.tar"
      },
      "sites-somalier": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/somalier/sites.hg38.vcf.gz"
      },
      "reference-somalier": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/dragen/hsapiens/hg38/hg38.fa"
      }
    }
    EOT
    prod = <<-EOT
    {
      "sample-name": "PLACEHOLDER",
      "fastq-directory": {
        "class": "Directory",
        "location": "PLACEHOLDER"
      },
      "fastq-list": {
        "class": "File",
        "location": "PLACEHOLDER"
      },
      "refdata-dragen": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/dragen/hsapiens/hg38/3.5.2_ht.tar"
      },
      "sites-somalier": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/somalier/sites.hg38.vcf.gz"
      },
      "reference-somalier": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/dragen/hsapiens/hg38/hg38.fa"
      }
    }
    EOT
  }
}

#--- BCL Convert

resource "aws_ssm_parameter" "bcl_convert_id" {
  name = "/iap/workflow/bcl_convert/id"
  type = "String"
  description = "BCL Convert Workflow ID"
  value = local.bcl_convert_wfl_id[terraform.workspace]
}

resource "aws_ssm_parameter" "bcl_convert_version" {
  name = "/iap/workflow/bcl_convert/version"
  type = "String"
  description = "BCL Convert Workflow Version Name"
  value = local.bcl_convert_wfl_version[terraform.workspace]
}

resource "aws_ssm_parameter" "bcl_convert_input" {
  name = "/iap/workflow/bcl_convert/input"
  type = "String"
  description = "BCL Convert Workflow Input JSON"
  value = local.bcl_convert_input[terraform.workspace]
}

# --- Germline

resource "aws_ssm_parameter" "germline_id" {
  name = "/iap/workflow/germline/id"
  type = "String"
  description = "Germline Workflow ID"
  value = local.germline_wfl_id[terraform.workspace]
}

resource "aws_ssm_parameter" "germline_version" {
  name = "/iap/workflow/germline/version"
  type = "String"
  description = "Germline Workflow Version Name"
  value = local.germline_wfl_version[terraform.workspace]
}

resource "aws_ssm_parameter" "germline_input" {
  name = "/iap/workflow/germline/input"
  type = "String"
  description = "Germline Input JSON"
  value = local.germline_input[terraform.workspace]
}

terraform {
  required_version = ">= 0.15"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_portal_workflow_automation/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.37.0"
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
    dev  = "3.7.5"
    prod = "3.7.5-9118962"
  }

  bcl_convert_input = {
    dev = <<-EOT
    {
      "bcl_input_directory": {
        "class": "Directory",
        "location": "PLACEHOLDER"
      },
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
      "runfolder_name": "PLACEHOLDER"
    }
    EOT
    prod = <<-EOT
    {
      "bcl_input_directory": {
        "class": "Directory",
        "location": "PLACEHOLDER"
      },
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
      "runfolder_name": "PLACEHOLDER"
    }
    EOT
  }

  germline_wfl_id = {
    dev  = "wfl.5cc28c147e4e4dfa9e418523188aacec"
    prod = "wfl.d6f51b67de5b4d309dddf4e411362be7"
  }

  germline_wfl_version = {
    dev  = "3.7.5--1.3.5"
    prod = "3.7.5--1.3.5-65a0f81"
  }

  germline_input = {
    dev = <<-EOT
    {
      "sample_name": null,
      "fastq_list_rows": null,
      "sites_somalier": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/somalier/sites.hg38.vcf.gz"
      },
      "genome_version": "hg38",
      "hla_reference_fasta": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/optitype/hla_reference_dna.fasta"
      },
      "reference_fasta": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/dragen/genomes/hg38/hg38.fa"
      },
      "reference_tar_dragen": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/dragen/genomes/hg38/3.7.5/hg38_alt_ht_3_7_5.tar.gz"
      }
    }
    EOT
    prod = <<-EOT
    {
      "sample_name": null,
      "fastq_list_rows": null,
      "sites_somalier": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/somalier/sites.hg38.vcf.gz"
      },
      "genome_version": "hg38",
      "hla_reference_fasta": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/optitype/hla_reference_dna.fasta"
      },
      "reference_fasta": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/dragen/genomes/hg38/hg38.fa"
      },
      "reference_tar_dragen": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/dragen/genomes/hg38/3.7.5/hg38_alt_ht_3_7_5.tar.gz"
      }
    }
    EOT
  }

  tumor_normal_wfl_id = {
    dev  = "wfl.32e346cdbb854f6487e7594ec17a81f9"
    prod = "wfl.32e346cdbb854f6487e7594ec17a81f9"
  }

  tumor_normal_wfl_version = {
    dev  = "3.7.5"
    prod = "3.7.5--5a56dd"
  }

  tumor_normal_input = {
    dev = <<-EOT
    {
        "output_file_prefix": null,
        "output_directory": null,
        "fastq_list_rows": [],
        "tumor_fastq_list_rows": [],
        "enable_map_align_output": true,
        "enable_duplicate_marking": true,
        "enable_sv": true,
        "reference_tar": {
            "class": "File",
            "location": "gds://umccr-refdata-dev/dragen/genomes/hg38/3.7.5/hg38_alt_ht_3_7_5.tar.gz"
        }
    }
    EOT
    prod = <<-EOT
    {
        "output_file_prefix": null,
        "output_directory": null,
        "fastq_list_rows": [],
        "tumor_fastq_list_rows": [],
        "enable_map_align_output": true,
        "enable_duplicate_marking": true,
        "enable_sv": true,
        "reference_tar": {
            "class": "File",
            "location": "gds://umccr-refdata-prod/dragen/genomes/hg38/3.7.5/hg38_alt_ht_3_7_5.tar.gz"
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

# --- Tumor / Normal

resource "aws_ssm_parameter" "tumor_normal_id" {
  name = "/iap/workflow/tumor_normal/id"
  type = "String"
  description = "Tumor / Normal Workflow ID"
  value = local.tumor_normal_wfl_id[terraform.workspace]
}

resource "aws_ssm_parameter" "tumor_normal_version" {
  name = "/iap/workflow/tumor_normal/version"
  type = "String"
  description = "Tumor / Normal Workflow Version Name"
  value = local.tumor_normal_wfl_version[terraform.workspace]
}

resource "aws_ssm_parameter" "tumor_normal_input" {
  name = "/iap/workflow/tumor_normal/input"
  type = "String"
  description = "Tumor / Normal Input JSON"
  value = local.tumor_normal_input[terraform.workspace]
}

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
  # Stack name in under socre
  stack_name_us = "data_portal"

  # Stack name in dash
  stack_name_dash = "data-portal"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }

  token_desc = {
    dev  = "ICA token using development project"
    prod = "ICA token using production project"
  }

  token_tier = {
    # Standard -- 4096 characters limit
    # Advanced -- $0.05 per advanced parameter per month (prorated hourly if the parameter is stored less than a month)
    dev  = "Advanced"
    prod = "Advanced"
  }

  bcl_convert_wfl_id = {
    dev  = "wfl.59e481580c6243b6b237ca2b08fa1270"
    prod = "wfl.f257ca35ced94e648fdda1173144c476"
  }

  bcl_convert_wfl_version = {
    dev  = "3.7.5"
    prod = "3.7.5--f1e67a3"
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

  bcl_convert_engine_parameters = {
    dev = <<-EOT
    {
        "outputDirectory": "PLACEHOLDER"
    }
    EOT
    prod = <<-EOT
    {
        "outputDirectory": "PLACEHOLDER"
    }
    EOT
  }

  dragen_wgs_qc_wfl_id = {
    dev  = "wfl.ff6ca1789f4e4eb0982ea3e01407aca8"
    prod = "wfl.23f61cb1baab412a8c37dc93bed6c2af"
  }

  dragen_wgs_qc_wfl_version = {
    dev  = "3.7.5"
    prod = "3.7.5--67a9d2b"
  }

  dragen_wgs_qc_input = {
    dev = <<-EOT
    {
      "output_file_prefix": null,
      "output_directory": null,
      "fastq_list_rows": null,
      "sites_somalier": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/somalier/sites.hg38.vcf.gz"
      },
      "reference_fasta": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/dragen/genomes/hg38/hg38.fa"
      },
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
      "fastq_list_rows": null,
      "sites_somalier": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/somalier/sites.hg38.vcf.gz"
      },
      "reference_fasta": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/dragen/genomes/hg38/hg38.fa"
      },
      "reference_tar": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/dragen/genomes/hg38/3.7.5/hg38_alt_ht_3_7_5.tar.gz"
      }
    }
    EOT
  }

  tumor_normal_wfl_id = {
    dev  = "wfl.32e346cdbb854f6487e7594ec17a81f9"
    prod = "wfl.aa0ccece4e004839aa7374d1d6530633"
  }

  tumor_normal_wfl_version = {
    dev  = "3.7.5"
    prod = "3.7.5--1d8fe7b"
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

  dragen_wts_wfl_id = {
    dev  = "wfl.286d4a2e82f048609d5b288a9d2868f6"
    prod = "wfl.7e5ba7470b5549a6b4bf6d95daaa1214"
  }

  dragen_wts_wfl_version = {
    dev  = "3.7.5"
    prod = "3.7.5--1d8fe7b"
  }

  dragen_wts_input = {
    dev = <<-EOT
    {
      "fastq_list_rows": null,
      "output_file_prefix": null,
      "output_directory": null,
      "annotation_file": {
            "class": "File",
            "location": "gds://umccr-refdata-dev/dragen/hsapiens/hg38/rnaseq/ref-transcripts.non-zero-length.gtf"
        },
      "cytobands": {
            "class": "File",
            "location": "gds://umccr-refdata-dev/dragen/hsapiens/hg38/rnaseq/fusion/arriba-cytobands.tsv"
        },
      "blacklist": {
            "class": "File",
            "location": "gds://umccr-refdata-dev/dragen/hsapiens/hg38/rnaseq/fusion/arriba-blacklist.tsv.gz"
        },
      "protein_domains": {
            "class": "File",
            "location": "gds://umccr-refdata-dev/dragen/hsapiens/hg38/rnaseq/fusion/arriba-protein-domains.gff3"
        },
      "reference_fasta": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/dragen/genomes/hg38/hg38.fa"
      },
      "reference_tar": {
        "class": "File",
        "location": "gds://umccr-refdata-dev/dragen/genomes/hg38/3.7.5/hg38_alt_ht_3_7_5.tar.gz"
      }
    }
    EOT
    prod = <<-EOT
    {
      "fastq_list_rows": null,
      "output_file_prefix": null,
      "output_directory": null,
      "annotation_file": {
            "class": "File",
            "location": "gds://umccr-refdata-prod/dragen/transcript/ref-transcripts.non-zero-length.gtf"
        },
      "cytobands": {
            "class": "File",
            "location": "gds://umccr-refdata-prod/dragen/hsapiens/hg38/rnaseq/fusion/arriba-cytobands.tsv"
        },
      "blacklist": {
            "class": "File",
            "location": "gds://umccr-refdata-prod/dragen/hsapiens/hg38/rnaseq/fusion/arriba-blacklist.tsv.gz"
        },
      "protein_domains": {
            "class": "File",
            "location": "gds://umccr-refdata-prod/dragen/hsapiens/hg38/rnaseq/fusion/arriba-protein-domains.gff3"
        },
      "reference_fasta": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/dragen/genomes/hg38/hg38.fa"
      },
      "reference_tar": {
        "class": "File",
        "location": "gds://umccr-refdata-prod/dragen/genomes/hg38/3.7.5/hg38_alt_ht_3_7_5.tar.gz"
      }
    }
    EOT
  }

  dragen_tso_ctdna_wfl_id = {
    dev = "wfl.3cfe22e0ca1f43a8b68c1ec820a0a5dc"
    prod = "wfl.576020a89adb49c3b2081a620d19104d"
  }

  dragen_tso_ctdna_wfl_version = {
    dev = "1.1.0--120"
    prod = "1.1.0--120--1d8fe7b"
  }

  dragen_tso_ctdna_wfl_input = {
    dev = <<-EOT
    {
      "tso500_samples": null,
      "fastq_list_rows": null,
      "samplesheet_prefix": "BCLConvert",
      "samplesheet": null
      "resources_dir": {
          "class": "Directory",
          "location": "gds://resources/ruo-1.1.0.3?tenantId=YXdzLXVzLXBsYXRmb3JtOjEwMDAwNjg1OjZlMzg3NGU0LTZmYzYtNGYxOS05ZWVmLTZmNWNlN2Y3MGU4Zg"
      },
      "dragen_license_key": {
          "class": "File",
          "location": "gds://development/dragen-license/cttso/license_umccr.txt"
      }
    }
    EOT
    prod = <<-EOT
    {
      "tso500_samples": null,
      "fastq_list_rows": null,
      "samplesheet_prefix": "BCLConvert",
      "samplesheet": null
      "resources_dir": {
          "class": "Directory",
          "location": "gds://resources/ruo-1.1.0.3?tenantId=YXdzLXVzLXBsYXRmb3JtOjEwMDAwNjg1OjZlMzg3NGU0LTZmYzYtNGYxOS05ZWVmLTZmNWNlN2Y3MGU4Zg"
      },
      "dragen_license_key": {
          "class": "File",
          "location": "gds://production/dragen-license/cttso/license_umccr.txt"
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
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "bcl_convert_version" {
  name = "/iap/workflow/bcl_convert/version"
  type = "String"
  description = "BCL Convert Workflow Version Name"
  value = local.bcl_convert_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "bcl_convert_input" {
  name = "/iap/workflow/bcl_convert/input"
  type = "String"
  description = "BCL Convert Workflow Input JSON"
  value = local.bcl_convert_input[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "bcl_convert_engine_parameters" {
  name = "/iap/workflow/bcl_convert/engine_parameters"
  type = "String"
  description = "BCL Convert Workflow engine_parameters JSON"
  value = local.bcl_convert_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- DRAGEN WGS QC Workflow for WGS samples (used to call Germline initially)

resource "aws_ssm_parameter" "dragen_wgs_qc_id" {
  name = "/iap/workflow/dragen_wgs_qc/id"
  type = "String"
  description = "DRAGEN_WGS_QC Workflow ID"
  value = local.dragen_wgs_qc_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "dragen_wgs_qc_version" {
  name = "/iap/workflow/dragen_wgs_qc/version"
  type = "String"
  description = "DRAGEN_WGS_QC Workflow Version Name"
  value = local.dragen_wgs_qc_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "dragen_wgs_qc_input" {
  name = "/iap/workflow/dragen_wgs_qc/input"
  type = "String"
  description = "DRAGEN_WGS_QC Input JSON"
  value = local.dragen_wgs_qc_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- Tumor / Normal

resource "aws_ssm_parameter" "tumor_normal_id" {
  name = "/iap/workflow/tumor_normal/id"
  type = "String"
  description = "Tumor / Normal Workflow ID"
  value = local.tumor_normal_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "tumor_normal_version" {
  name = "/iap/workflow/tumor_normal/version"
  type = "String"
  description = "Tumor / Normal Workflow Version Name"
  value = local.tumor_normal_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "tumor_normal_input" {
  name = "/iap/workflow/tumor_normal/input"
  type = "String"
  description = "Tumor / Normal Input JSON"
  value = local.tumor_normal_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- DRAGEN WTS Workflow for Transcriptome samples

resource "aws_ssm_parameter" "dragen_wts_id" {
  name = "/iap/workflow/dragen_wts/id"
  type = "String"
  description = "DRAGEN WTS Workflow ID"
  value = local.dragen_wts_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "dragen_wts_version" {
  name = "/iap/workflow/dragen_wts/version"
  type = "String"
  description = "DRAGEN WTS Workflow Version Name"
  value = local.dragen_wts_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "dragen_wts_input" {
  name = "/iap/workflow/dragen_wts/input"
  type = "String"
  description = "DRAGEN WTS Input JSON"
  value = local.dragen_wts_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- DRAGEN_TSO_CTDNA

resource "aws_ssm_parameter" "dragen_tso_ctdna_id" {
  name = "/iap/workflow/dragen_tso_ctdna/id"
  type = "String"
  description = "Dragen ctTSO Workflow ID"
  value = local.dragen_tso_ctdna_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "dragen_tso_ctdna_version" {
  name = "/iap/workflow/dragen_tso_ctdna/version"
  type = "String"
  description = "Dragen ctTSO Workflow Version Name"
  value = local.dragen_tso_ctdna_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "dragen_tso_ctdna_input" {
  name = "/iap/workflow/dragen_tso_ctdna/input"
  type = "String"
  description = "Dragen ctTSO Input JSON"
  value = local.dragen_tso_ctdna_wfl_input[terraform.workspace]
  tags = merge(local.default_tags)
}

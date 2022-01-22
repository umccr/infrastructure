terraform {
  required_version = ">= 1.0.5"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_portal_workflow_automation/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.56.0"
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

  engine_parameters_default_workdir_root = {
    dev = "gds://development/temp"
    prod = "gds://production/temp"
  }

  engine_parameters_default_output_root = {
    dev = "gds://development"
    prod = "gds://production"
  }

  bcl_convert_wfl_id = {
    dev  = "wfl.59e481580c6243b6b237ca2b08fa1270"
    prod = "wfl.f257ca35ced94e648fdda1173144c476"
  }

  bcl_convert_wfl_version = {
    dev  = "3.7.5"
    prod = "3.7.5--f1e67a3"
  }

  bcl_convert_wfl_input = {
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
      "bcl_sampleproject_subdirectories_bcl_conversion": false,
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
      "bcl_sampleproject_subdirectories_bcl_conversion": false,
      "strict_mode_bcl_conversion": true,
      "delete_undetermined_indices_bcl_conversion": true,
      "runfolder_name": "PLACEHOLDER"
    }
    EOT
  }

  wgs_alignment_qc_wfl_id = {
    dev  = "wfl.ff6ca1789f4e4eb0982ea3e01407aca8"
    prod = "wfl.23f61cb1baab412a8c37dc93bed6c2af"
  }

  wgs_alignment_qc_wfl_version = {
    dev  = "3.9.3"
    prod = "3.9.3--0d6bc70"
  }

  wgs_alignment_qc_wfl_input = {
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
        "location": "gds://development/reference-data/dragen_hash_tables/v8/hg38/altaware-cnv-anchored/hg38-v8-altaware-cnv-anchored.tar.gz"
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
        "location": "gds://production/reference-data/dragen_hash_tables/v8/hg38/altaware-cnv-anchored/hg38-v8-altaware-cnv-anchored.tar.gz"
      }
    }
    EOT
  }

  wgs_tumor_normal_wfl_id = {
    dev  = "wfl.32e346cdbb854f6487e7594ec17a81f9"
    prod = "wfl.aa0ccece4e004839aa7374d1d6530633"
  }

  wgs_tumor_normal_wfl_version = {
    dev  = "3.9.3"
    prod = "3.9.3--61a372d"
  }

  wgs_tumor_normal_wfl_input = {
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
            "location": "gds://development/reference-data/dragen_hash_tables/v8/hg38/altaware-cnv-anchored/hg38-v8-altaware-cnv-anchored.tar.gz"
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
            "location": "gds://production/reference-data/dragen_hash_tables/v8/hg38/altaware-cnv-anchored/hg38-v8-altaware-cnv-anchored.tar.gz"
        }
    }
    EOT
  }

  wts_tumor_only_wfl_id = {
    dev  = "wfl.286d4a2e82f048609d5b288a9d2868f6"
    prod = "wfl.7e5ba7470b5549a6b4bf6d95daaa1214"
  }

  wts_tumor_only_wfl_version = {
    dev  = "3.9.3"
    prod = "3.9.3--9961e75"
  }

  wts_tumor_only_wfl_input = {
    dev = <<-EOT
    {
      "fastq_list_rows": null,
      "output_file_prefix": null,
      "output_directory": null,
      "annotation_file": {
            "class": "File",
            "location": "gds://development/reference-data/dragen_wts/hg38/ref-transcripts.non-zero-length.gtf"
        },
      "cytobands": {
            "class": "File",
            "location": "gds://development/reference-data/dragen_wts/arriba/hg38/arriba-cytobands.tsv"
        },
      "blacklist": {
            "class": "File",
            "location": "gds://development/reference-data/dragen_wts/arriba/hg38/arriba-blacklist.tsv.gz"
        },
      "protein_domains": {
            "class": "File",
            "location": "gds://development/reference-data/dragen_wts/arriba/hg38/arriba-protein-domains.gff3"
        },
      "reference_fasta": {
        "class": "File",
        "location": "gds://development/reference-data/genomes/hg38/hg38.fa"
      },
      "reference_tar": {
        "class": "File",
        "location": "gds://development/reference-data/dragen_hash_tables/v8/hg38/altaware-cnv-anchored/hg38-v8-altaware-cnv-anchored.tar.gz"
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
            "location": "gds://production/reference-data/dragen_wts/hg38/ref-transcripts.non-zero-length.gtf"
        },
      "cytobands": {
            "class": "File",
            "location": "gds://production/reference-data/dragen_wts/arriba/hg38/arriba-cytobands.tsv"
        },
      "blacklist": {
            "class": "File",
            "location": "gds://production/reference-data/dragen_wts/arriba/hg38/arriba-blacklist.tsv.gz"
        },
      "protein_domains": {
            "class": "File",
            "location": "gds://production/reference-data/dragen_wts/arriba/hg38/arriba-protein-domains.gff3"
        },
      "reference_fasta": {
        "class": "File",
        "location": "gds://production/reference-data/genomes/hg38/hg38.fa"
      },
      "reference_tar": {
        "class": "File",
        "location": "gds://production/reference-data/dragen_hash_tables/v8/hg38/altaware-cnv-anchored/hg38-v8-altaware-cnv-anchored.tar.gz"
      }
    }
    EOT
  }

  tso_ctdna_tumor_only_wfl_id = {
    dev = "wfl.b0be3d1bbd8140bbaa64038f0eb8f7c2"
    prod = "wfl.230846758ccf42e3831283ab0e45af0a"
  }

  tso_ctdna_tumor_only_wfl_version = {
    dev = "1.1.0--1.0.0"
    prod = "1.1.0--1.0.0--9c97fe9"
  }

  tso_ctdna_tumor_only_wfl_input = {
    dev = <<-EOT
    {
      "tso500_samples": null,
      "fastq_list_rows": null,
      "samplesheet_prefix": "BCLConvert",
      "samplesheet": null,
      "resources_dir": {
          "class": "Directory",
          "location": "gds://development/reference-data/dragen_tso_ctdna/ruo-1.1.0.3/"
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
      "samplesheet": null,
      "resources_dir": {
          "class": "Directory",
          "location": "gds://production/reference-data/dragen_tso_ctdna/ruo-1.1.0.3/"
      },
      "dragen_license_key": {
          "class": "File",
          "location": "gds://production/dragen-license/cttso/license_umccr.txt"
      }
    }
    EOT
  }

  umccrise_wfl_id = {
    dev = "wfl.e4cd73b0e6e941b3b48afe03a7b5dc43"
    prod = "wfl.7ed9c6014ac9498fbcbd4c17c28bc0d4"
  }

  umccrise_wfl_version = {
    dev = "2.0.0--3.9.3"
    prod = "2.0.0--3.9.3--5d22f74"
  }

  umccrise_wfl_input = {
    dev = <<-EOT
    {
      "dragen_somatic_directory": null,
      "fastq_list_rows_germline": null,
      "output_directory_germline": null,
      "output_directory_umccrise": null,
      "output_file_prefix_germline": null,
      "reference_tar_germline": {
        "class": "File",
        "location": "gds://development/reference-data/dragen_hash_tables/v8/hg38/altaware-cnv-anchored/hg38-v8-altaware-cnv-anchored.tar.gz"
      },
      "reference_tar_umccrise": {
        "class": "File",
        "location": "gds://development/reference-data/umccrise/1.0.10/genomes.tar.gz"
      },
      "subject_identifier_umccrise": null
    }
    EOT
    prod = <<-EOT
    {
      "dragen_somatic_directory": null,
      "fastq_list_rows_germline": null,
      "output_directory_germline": null,
      "output_directory_umccrise": null,
      "output_file_prefix_germline": null,
      "reference_tar_germline": {
        "class": "File",
        "location": "gds://production/reference-data/dragen_hash_tables/v8/hg38/altaware-cnv-anchored/hg38-v8-altaware-cnv-anchored.tar.gz"
      },
      "reference_tar_umccrise": {
        "class": "File",
        "location": "gds://production/reference-data/umccrise/1.0.10/genomes.tar.gz"
      },
      "subject_identifier_umccrise": null
    }
    EOT
  }
}

#--- Engine Parameter defaults

resource "aws_ssm_parameter" "workdir_root" {
  name = "/iap/workflow/workdir_root"
  type = "String"
  description = "Root directory for intermediate files for ica workflow"
  value = local.engine_parameters_default_workdir_root[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "output_root" {
  name = "/iap/workflow/output_root"
  type = "String"
  description = "Root directory for output files for ica workflow"
  value = local.engine_parameters_default_output_root[terraform.workspace]
  tags = merge(local.default_tags)
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
  value = local.bcl_convert_wfl_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- DRAGEN WGS QC Workflow for WGS samples (used to call Germline initially)

resource "aws_ssm_parameter" "wgs_alignment_qc_wfl_id" {
  name = "/iap/workflow/wgs_alignment_qc/id"
  type = "String"
  description = "DRAGEN_WGS_QC Workflow ID"
  value = local.wgs_alignment_qc_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wgs_alignment_qc_wfl_version" {
  name = "/iap/workflow/wgs_alignment_qc/version"
  type = "String"
  description = "DRAGEN_WGS_QC Workflow Version Name"
  value = local.wgs_alignment_qc_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wgs_alignment_qc_wfl_input" {
  name = "/iap/workflow/wgs_alignment_qc/input"
  type = "String"
  description = "DRAGEN_WGS_QC Input JSON"
  value = local.wgs_alignment_qc_wfl_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- Tumor / Normal

resource "aws_ssm_parameter" "wgs_tumor_normal_wfl_id" {
  name = "/iap/workflow/wgs_tumor_normal/id"
  type = "String"
  description = "Tumor / Normal Workflow ID"
  value = local.wgs_tumor_normal_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wgs_tumor_normal_wfl_version" {
  name = "/iap/workflow/wgs_tumor_normal/version"
  type = "String"
  description = "Tumor / Normal Workflow Version Name"
  value = local.wgs_tumor_normal_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wgs_tumor_normal_wfl_input" {
  name = "/iap/workflow/wgs_tumor_normal/input"
  type = "String"
  description = "Tumor / Normal Input JSON"
  value = local.wgs_tumor_normal_wfl_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- DRAGEN WTS Workflow for Transcriptome samples

resource "aws_ssm_parameter" "wts_tumor_only_wfl_id" {
  name = "/iap/workflow/wts_tumor_only/id"
  type = "String"
  description = "DRAGEN WTS Workflow ID"
  value = local.wts_tumor_only_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wts_tumor_only_wfl_version" {
  name = "/iap/workflow/wts_tumor_only/version"
  type = "String"
  description = "DRAGEN WTS Workflow Version Name"
  value = local.wts_tumor_only_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "wts_tumor_only_wfl_input" {
  name = "/iap/workflow/wts_tumor_only/input"
  type = "String"
  description = "DRAGEN WTS Input JSON"
  value = local.wts_tumor_only_wfl_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- DRAGEN_TSO_CTDNA

resource "aws_ssm_parameter" "tso_ctdna_tumor_only_wfl_id" {
  name = "/iap/workflow/tso_ctdna_tumor_only/id"
  type = "String"
  description = "Dragen ctTSO Workflow ID"
  value = local.tso_ctdna_tumor_only_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "tso_ctdna_tumor_only_wfl_version" {
  name = "/iap/workflow/tso_ctdna_tumor_only/version"
  type = "String"
  description = "Dragen ctTSO Workflow Version Name"
  value = local.tso_ctdna_tumor_only_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "tso_ctdna_tumor_only_wfl_input" {
  name = "/iap/workflow/tso_ctdna_tumor_only/input"
  type = "String"
  description = "Dragen ctTSO Input JSON"
  value = local.tso_ctdna_tumor_only_wfl_input[terraform.workspace]
  tags = merge(local.default_tags)
}

# --- UMCCRISE

resource "aws_ssm_parameter" "umccrise_wfl_id" {
  name = "/iap/workflow/umccrise/id"
  type = "String"
  description = "UMCCRise Workflow ID"
  value = local.umccrise_wfl_id[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "umccrise_wfl_version" {
  name = "/iap/workflow/umccrise/version"
  type = "String"
  description = "UMCCRise Workflow Version Name"
  value = local.umccrise_wfl_version[terraform.workspace]
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "umccrise_wfl_input" {
  name = "/iap/workflow/umccrise/input"
  type = "String"
  description = "UMCCRise Input JSON"
  value = local.umccrise_wfl_input[terraform.workspace]
  tags = merge(local.default_tags)
}

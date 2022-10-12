locals {
  contig_mean_cov_tables = toset([
    "dragen_somatic",
    "dragen_umccrise",
  ])

  s3_contig_mean_cov_base = "s3://${data.aws_s3_bucket.datalake.bucket}/${local.datalake_version}/contig_mean_cov"
}

resource "aws_glue_catalog_database" "contig_mean_cov" {
  name = "contig_mean_cov"
}

resource "aws_glue_crawler" "contig_mean_cov_crawlers" {
  for_each = local.contig_mean_cov_tables

  database_name = aws_glue_catalog_database.contig_mean_cov.name
  name          = "${each.value}_contig_mean_cov_crawler"
  role          = aws_iam_role.datalake_role.arn

  # https://docs.aws.amazon.com/glue/latest/dg/crawler-configuration.html
  configuration = jsonencode(
    {
      Grouping = {
        TableGroupingPolicy = "CombineCompatibleSchemas"
      }
      CrawlerOutput = {
        Partitions = { AddOrUpdateBehavior = "InheritFromTable" },
        Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
      }
      Version = 1
    }
  )

  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_crawler#schema-change-policy
  # https://docs.aws.amazon.com/glue/latest/dg/crawler-configuration.html#crawler-configure-changes-api
  schema_change_policy {
    delete_behavior = "DEPRECATE_IN_DATABASE"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_crawler#lineage-configuration
  lineage_configuration {
    crawler_lineage_settings = "DISABLE"
  }

  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_crawler#recrawl-policy
  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  s3_target {
    # https://docs.aws.amazon.com/glue/latest/dg/crawler-configuration.html#crawler-table-level
    path = "${local.s3_contig_mean_cov_base}/${each.value}"

    # https://docs.aws.amazon.com/glue/latest/dg/define-crawler.html#crawler-data-stores-exclude
    exclusions = ["*.{tsv,csv,avro,json,orc}"]
  }
}

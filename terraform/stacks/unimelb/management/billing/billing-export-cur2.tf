data "local_file" "data_export_cur2_sql" {
  filename = "${path.module}/../../../../common/data_export/cur2.sql"
}

resource "aws_bcmdataexports_export" "cur2_export" {
  export {
    name = "cur2-include-resource-ids-hourly"

    data_query {
      query_statement = data.local_file.data_export_cur2_sql.content
      table_configurations = {
        COST_AND_USAGE_REPORT = {
          BILLING_VIEW_ARN                      = "arn:${data.aws_partition.current.partition}:billing::${data.aws_caller_identity.current.account_id}:billingview/primary"
          TIME_GRANULARITY                      = "HOURLY"
          INCLUDE_RESOURCES                     = "TRUE"
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
          # because UoM delivers data via billing conductor - we cannot get the split cost
          # allocation data (we would if we could)
          INCLUDE_SPLIT_COST_ALLOCATION_DATA = "FALSE"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = aws_s3_bucket.billing_export.bucket
        # the data will *also* be prefixed by the name of the export so there is no need
        # for anything here to distinguish it
        s3_prefix = ""
        s3_region = aws_s3_bucket.billing_export.bucket_region
        s3_output_configurations {
          overwrite   = "OVERWRITE_REPORT"
          format      = "PARQUET"
          compression = "PARQUET"
          output_type = "CUSTOM"
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }
}

data "local_file" "data_export_carbon_sql" {
  filename = "${path.module}/../../../../common/data_export/carbon.sql"
}

resource "aws_bcmdataexports_export" "carbon_export" {
  export {
    name = "carbon"

    data_query {
      query_statement = data.local_file.data_export_carbon_sql.content
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

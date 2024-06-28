locals {
  cloudtrail_bucket_name          = "cloudtrail-logs-${local.mgmt_account_id}-${local.region}"
  data_trail_name                 = "dataTrail"
  event_bus_arn_umccr_org_default = "arn:aws:events:ap-southeast-2:${local.account_id_org}:event-bus/default"
}


################################################################################
# Security resources

resource "aws_cloudtrail" "dataTrail" {
  name           = local.data_trail_name
  s3_bucket_name = local.cloudtrail_bucket_name

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }
  tags = merge(
    local.default_tags,
    {
      "umccr:Name" = local.data_trail_name
    }
  )
}


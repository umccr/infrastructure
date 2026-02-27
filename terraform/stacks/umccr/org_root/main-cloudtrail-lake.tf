################################################################################
# Cloud Trail Lake
# A lake for querying

resource "aws_cloudtrail_event_data_store" "org_trail_store" {
  name = "umccr-cloudtrail-org-root-event-data-store"

  retention_period     = 7
  multi_region_enabled = true
  organization_enabled = true

  # until we work out we want this we allow it to be deleted
  termination_protection_enabled = false

  dynamic "advanced_event_selector" {
    for_each = local.common_advanced_event_selectors
    content {
      name = advanced_event_selector.value.name

      dynamic "field_selector" {
        for_each = advanced_event_selector.value.field_selectors
        content {
          field  = field_selector.value.field
          equals = try(field_selector.value.equals, null)
          not_equals = try(field_selector.value.not_equals, null)
          starts_with = try(field_selector.value.starts_with, null)
          ends_with = try(field_selector.value.ends_with, null)
          not_starts_with = try(field_selector.value.not_starts_with, null)
          not_ends_with = try(field_selector.value.not_ends_with, null)
        }
      }
    }
  }

}

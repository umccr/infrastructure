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

  advanced_event_selector {
    name = "Log all management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  advanced_event_selector {
    name = "Log all S3 data events"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
  }

  advanced_event_selector {
    name = "Log all lambda data events"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::Lambda::Function"]
    }
  }

  advanced_event_selector {
    name = "Log all steps activity data events"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::StepFunctions::Activity"]
    }
  }

  advanced_event_selector {
    name = "Log all steps state machine data events"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::StepFunctions::StateMachine"]
    }
  }

}

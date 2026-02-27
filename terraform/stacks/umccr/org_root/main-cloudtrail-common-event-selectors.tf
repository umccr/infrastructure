locals {

  # a single common definition of cloud trail events we want to capture at an organisation level
  # can be shared between cloudtrails and cloudtrail lakes
  common_advanced_event_selectors = [
    {
      name = "Log all management and data events"

      # include management events
      field_selectors = [{
        field  = "eventCategory"
        equals = ["Management"]
      }]
    },

    {
      name = "Log all S3 data events"

      field_selectors = [{
        field  = "eventCategory"
        equals = ["Data"]
        },

        {
          field  = "resources.type"
          equals = ["AWS::S3::Object"]
      }]
    },

    {
      name = "Log all Lambda data events"

      field_selectors = [{
        field  = "eventCategory"
        equals = ["Data"]
        },

        {
          field  = "resources.type"
          equals = ["AWS::Lambda::Function"]
      }]
    },

    # log steps activity data events
    {
      name = "Log all Steps activity data events"

      field_selectors = [{
        field  = "eventCategory"
        equals = ["Data"]
        },
        {
          field  = "resources.type"
          equals = ["AWS::StepFunctions::Activity"]
      }]
    },

    # log steps state machine data events
    {
      name = "Log all Steps state machine data events"

      field_selectors = [{
        field  = "eventCategory"
        equals = ["Data"]
        },
        {
          field  = "resources.type"
          equals = ["AWS::StepFunctions::StateMachine"]
      }]
    }
  ]
}

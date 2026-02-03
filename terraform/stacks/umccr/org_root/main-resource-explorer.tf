################################################################################
# Resource Explorer
#
# Plan here should be to extend this to organisation wide resource explorer
# and set up some useful views
#
# Resource explorer is free so we should use it for diagnostics where we can

resource "aws_resourceexplorer2_index" "all" {
  type = "AGGREGATOR"
}

resource "aws_resourceexplorer2_view" "all" {
  name = "all-resources"

  default_view = true

  included_property {
    name = "tags"
  }

  depends_on = [aws_resourceexplorer2_index.all]
}

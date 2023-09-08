variable "elsa_data_data_bucket_paths" {
  default = {
    umccr-10f-data-dev = ["ASHKENAZIM/*", "CHINESE/*"]
    umccr-10g-data-dev = ["*"]
  }
}

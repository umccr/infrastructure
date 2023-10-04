variable "elsa_data_data_bucket_paths" {
  default = {
    org.umccr.demo.elsa-data-demo-data = ["*"]
    umccr-10f-data-dev = ["ASHKENAZIM/*", "CHINESE/*"]
    umccr-10g-data-dev = ["*"]
  }
}

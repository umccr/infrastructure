variable "raw_data_bucket_name" {
  description = "The name of the bucket for raw sequencer output (BCLs)."
  default     = "org.umccr.data.raw-data-archive"
}

variable "oncoanalyser_bucket_name" {
  description = "The name of the bucket for OncoAnalyser output."
  default     = "org.umccr.data.oncoanalyser"
}

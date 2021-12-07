myRcode <- function(input, output) {
  library("TidyMultiqc")
  library("arrow")
  #library("paws")

  df = load_multiqc(input)
  write_parquet(df, output)
}


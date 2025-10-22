knit <- function(input) {
  rmarkdown::render(
    input,
    output_file = "output.pdf",
    output_dir = "..",
    knit_root_dir = rprojroot::find_rstudio_root_file()
  )
}
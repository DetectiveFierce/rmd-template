knit <- function(input) {
  input_abs <- normalizePath(input, mustWork = TRUE)

  # Keep output in the project root regardless of the current working directory.
  output_dir <- normalizePath(file.path(dirname(input_abs), ".."), mustWork = TRUE)

  rmarkdown::render(
    input_abs,
    output_file = "output.pdf",
    output_dir = output_dir,
    knit_root_dir = rprojroot::find_rstudio_root_file(),
    quiet = TRUE
  )
}

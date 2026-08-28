# The package SOURCE tree, or "" when the tests run against an install alone (R CMD check unpacks
# only the built package, so nothing under R/ or _extensions/ is there). Every test that compares a
# generated file with its source skips on "".
src_root <- function() {
  p <- normalizePath("../..", mustWork = FALSE)
  if (file.exists(file.path(p, "R", "aaa-palette.R"))) p else ""
}
skip_without_source <- function() testthat::skip_if(src_root() == "", "no source tree")

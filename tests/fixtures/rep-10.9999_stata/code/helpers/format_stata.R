# Minimal Stata format helper for package tests (rep-10.9999_stata fixture).

format_tab_2_stata <- function(object) {
  path <- if (is.character(object)) object else object$output_path
  lines <- readLines(path, warn = FALSE)
  escaped <- gsub("&", "&amp;", lines, fixed = TRUE)
  escaped <- gsub("<", "&lt;", escaped, fixed = TRUE)
  escaped <- gsub(">", "&gt;", escaped, fixed = TRUE)
  paste0("<pre>", paste(escaped, collapse = "\n"), "</pre>")
}

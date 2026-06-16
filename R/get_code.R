#' Retrieve replication code for a paper
#'
#' Returns the analysis script and, when defined, the format script.
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (e.g., \code{"fig_1"}).
#' @return A character vector containing the lines of the replication script(s).
#' @export
get_code <- function(doi, what) {
  meta <- get_replication_meta(doi)
  rep <- find_replication_entry(meta, what)
  ctx <- paper_context(doi)

  read_code_file <- function(path) {
    if (!is.null(ctx$local_root)) {
      local_code <- file.path(ctx$local_root, path)
      if (file.exists(local_code)) {
        return(readLines(local_code, warn = FALSE))
      }
    }
    code_url <- paste0(ctx$base_url, "/", path)
    suppressWarnings(readLines(code_url, warn = FALSE))
  }

  lines <- read_code_file(rep$code)
  fmt_path <- format_script_path(rep)
  if (!is.null(fmt_path) && fmt_path != rep$code) {
    lines <- c(lines, "", read_code_file(fmt_path))
  }
  lines
}

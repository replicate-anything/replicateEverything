#' Retrieve replication code for a paper
#'
#' Returns the analysis script and, when defined, the format script.
#'
#' For package-backed studies, reads \code{inst/replication_code/*.R} from the
#' study package GitHub repo when the package is not installed (same idea as
#' reading \code{code/*.R} from the registry repo).
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (e.g., \code{"fig_1"}).
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @return A character vector containing the lines of the replication script(s).
#' @export
get_code <- function(doi, what, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    if (requireNamespace(pkg, quietly = TRUE)) {
      return(call_replication_package(pkg, "get_code", what))
    }
    return(get_code_from_package_repo(meta, ctx, what, pkg))
  }

  rep <- find_replication_entry(meta, what)

  read_code_file <- function(path) {
    if (!is.null(ctx$local_root)) {
      local_code <- file.path(ctx$local_root, path)
      if (file.exists(local_code)) {
        return(readLines(local_code, warn = FALSE))
      }
    }
    code_url <- paste0(ctx$base_url, "/", path)
    read_lines_url(code_url)
  }

  lines <- read_code_file(rep$code)
  fmt_path <- format_script_path(rep)
  if (!is.null(fmt_path) && fmt_path != rep$code) {
    lines <- c(lines, "", read_code_file(fmt_path))
  }
  lines
}

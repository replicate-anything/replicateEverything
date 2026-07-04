#' Replicate all results from a paper
#'
#' Runs one replication per logical figure/table group, using the default
#' engine (R when both R and Stata exist).
#'
#' @param doi Character. DOI of the paper.
#' @param language Optional \code{"R"} or \code{"stata"} for all groups.
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#'
#' @return A named list of replication result envelopes.
#'
#' @examples
#' \dontrun{
#' replicate_paper("10.1177/00491241211036161")
#' }
#'
#' @export
replicate_paper <- function(doi, language = NULL, install_deps = FALSE) {
  doi <- normalize_doi(doi)
  meta <- get_replication_meta(doi)

  message("Replicating: ", meta$paper$title)
  message("")

  groups <- list_replication_groups(doi, language = language)
  results <- lapply(groups, function(rep) {
    what <- replication_logical_id(rep)
    message("Running: ", what)
    render_replication(doi, what, language = language, install_deps = install_deps)
  })

  names(results) <- vapply(groups, replication_logical_id, character(1))
  invisible(results)
}

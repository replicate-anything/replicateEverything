#' Replicate all results from a paper
#'
#' Runs all registered replications (figures and tables) for a given paper.
#'
#' @param doi Character. DOI of the paper.
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#'
#' @return A named list of replication result envelopes.
#' @export
replicate_paper <- function(doi, install_deps = FALSE) {
  doi <- normalize_doi(doi)
  meta <- get_replication_meta(doi)

  message("Replicating: ", meta$paper$title)
  message("")

  results <- lapply(meta$replications, function(rep) {
    message("Running: ", rep$id)
    render_replication(doi, rep$id, install_deps = install_deps)
  })

  names(results) <- vapply(meta$replications, function(x) x$id, character(1))
  invisible(results)
}

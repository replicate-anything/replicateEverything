#' Replicate all results from a paper
#'
#' @description
#' **Deprecated.** Use [run_replication()] with `what = "everything"` instead.
#'
#' @param doi Character. DOI of the paper.
#' @param language Optional \code{"R"} or \code{"stata"} for all groups.
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#'
#' @return A named list of replication result envelopes (legacy behaviour).
#'
#' @examples
#' \dontrun{
#' replicate_paper("10.1177/00491241211036161")
#' run_replication("10.1177/00491241211036161", "everything")
#' }
#'
#' @export
replicate_paper <- function(doi, language = NULL, install_deps = FALSE) {
  .Deprecated(
    msg = paste0(
      "replicate_paper() is deprecated. ",
      "Use run_replication(doi, what = \"everything\") instead."
    )
  )

  doi_key <- prepare_doi_for_replication(doi)
  meta <- get_replication_meta(doi_key)

  message("Replicating: ", meta$paper$title)
  message("")

  groups <- list_replication_groups(doi_key, language = language)
  results <- lapply(groups, function(rep) {
    what <- replication_logical_id(rep)
    message("Running: ", what)
    render_replication(doi_key, what, language = language, install_deps = install_deps)
  })

  names(results) <- vapply(groups, replication_logical_id, character(1))
  invisible(results)
}

#' Run a single replication
#'
#' Executes a specific replication (figure or table) for a paper.
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (e.g., "fig_1").
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#'
#' @return The underlying replication object.
#' @export
run_replication <- function(doi, what, install_deps = FALSE) {
  result <- render_replication(doi, what, install_deps = install_deps)
  object <- replication_object(result)
  print(object)
  invisible(object)
}

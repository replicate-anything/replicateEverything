#' Validate that a replication can be rendered
#'
#' @param doi Character. DOI of the paper.
#' @param what Replication identifier.
#' @param install_deps Logical. Passed to \code{render_replication()}.
#'
#' @return Invisibly \code{TRUE} on success.
#' @export
validate_replication <- function(doi, what, install_deps = FALSE) {
  render_replication(doi, what, install_deps = install_deps)
  invisible(TRUE)
}

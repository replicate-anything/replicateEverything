#' Validate that a replication can be rendered
#'
#' @param doi Character. DOI of the paper.
#' @param what Replication identifier.
#' @param install_deps Logical. Passed to \code{render_replication()}.
#'
#' @return Invisibly \code{TRUE} on success.
#'
#' @examples
#' \dontrun{
#' validate_replication("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @export
validate_replication <- function(doi, what, language = NULL, install_deps = FALSE) {
  render_replication(doi, what, language = language, install_deps = install_deps)
  invisible(TRUE)
}

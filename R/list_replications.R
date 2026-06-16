#' List available replications for a paper
#'
#' @param doi Character. DOI of the paper.
#' @return A list of replication entries from \code{replication.yml}.
#' @export
list_replications <- function(doi) {
  meta <- get_replication_meta(doi)
  meta$replications
}

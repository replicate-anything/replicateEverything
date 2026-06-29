#' List available replications for a paper
#'
#' @param doi Character. DOI of the paper.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @return A list of replication entries from \code{replication.yml}.
#'
#' @examples
#' \dontrun{
#' list_replications("10.1177/00491241211036161")
#' }
#'
#' @export
list_replications <- function(doi, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  reps <- c(meta$prep %||% list(), meta$replications %||% list())
  display_reps <- reps[vapply(reps, function(x) {
    type <- as.character(x$type %||% "")
    type %in% c("figure", "table")
  }, logical(1))]
  if (length(display_reps) > 0) {
    return(reps)
  }
  if (is_package_replication(meta)) {
    ctx <- paper_context(doi, repo = repo, folder = folder)
    pkg_meta <- fetch_package_replication_yaml(meta, ctx)
    if (!is.null(pkg_meta)) {
      return(c(pkg_meta$prep %||% list(), pkg_meta$replications %||% list()))
    }
    pkg <- as.character(meta$paper$package[[1]])
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    if (requireNamespace(pkg, quietly = TRUE)) {
      return(call_replication_package(pkg, "list_replications"))
    }
  }
  reps
}

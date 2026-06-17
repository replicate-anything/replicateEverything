#' List available replications for a paper
#'
#' @param doi Character. DOI of the paper.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @return A list of replication entries from \code{replication.yml}.
#' @export
list_replications <- function(doi, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    ctx <- paper_context(doi, repo = repo, folder = folder)
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    return(call_replication_package(pkg, "list_replications"))
  }
  c(meta$prep %||% list(), meta$replications %||% list())
}

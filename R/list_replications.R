#' List available replications for a paper
#'
#' Retrieves the replication metadata for a paper and lists all
#' available figures and tables that can be reproduced.
#'
#' @param doi Character. DOI of the paper.
#'
#' @return A list of replication identifiers.
#'
#' @examples
#' \dontrun{
#' list_replications("10.1177/00491241211036161")
#' }
#'
#' @export
list_replications <- function(doi){

  repo <- find_repo(doi)

  doi_path <- gsub("/", "_", doi)

  meta_url <- paste0(
    "https://raw.githubusercontent.com/",
    repo,
    "/main/papers/",
    doi_path,
    "/replication.yml"
  )

  suppressWarnings(print(meta_url))

  meta <- yaml::read_yaml(meta_url)

  meta$replications

}

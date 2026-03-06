#' List replications for a paper
#'
#' Returns all figures and tables available for replication.
#'
#' @param doi Character DOI of the paper.
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

  print(meta_url)

  meta <- yaml::read_yaml(meta_url)

  meta$replications

}

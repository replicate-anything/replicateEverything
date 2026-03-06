#' Retrieve replication code
#'
#' Downloads the replication script for a specific output.
#'
#' @param doi Character DOI of the paper.
#' @param what Replication ID.
#'
#' @export
get_code <- function(doi, what){

  repo <- find_repo(doi)

  doi_path <- gsub("/", "_", doi)

  code_url <- paste0(
    "https://raw.githubusercontent.com/",
    repo,
    "/main/papers/",
    doi_path,
    "/code/",
    what,
    ".R"
  )

  suppressWarnings (readLines(code_url))

}


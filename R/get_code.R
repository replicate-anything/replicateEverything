#' Retrieve replication code for a paper
#'
#' Downloads and returns the replication script associated with a
#' specific figure or table from the replication registry.
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (e.g., \code{"fig_1"}).
#'
#' @return A character vector containing the lines of R code from the
#' replication script.
#'
#' @details
#' The function locates the appropriate replication repository using
#' \code{find_repo()}, constructs the URL to the replication script,
#' and downloads the script from the registry.
#'
#' @examples
#' \dontrun{
#' get_code("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
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


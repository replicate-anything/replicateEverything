#' Retrieve metadata for a DOI
#'
#' Fetches bibliographic metadata for a research paper using its DOI.
#' The function queries a DOI resolver and returns basic metadata
#' including the paper title, journal, publication year, and authors.
#'
#' @param doi Character. DOI of the paper.
#'
#' @return A list containing:
#' \describe{
#'   \item{title}{Title of the paper}
#'   \item{journal}{Journal name}
#'   \item{year}{Publication year}
#'   \item{authors}{Vector of author names}
#' }
#'
#' @details
#' This function is primarily used by \code{create_replication_template()}
#' to automatically populate metadata in the \code{replication.yml}
#' file when creating a new replication.
#'
#' @examples
#' \dontrun{
#' get_doi_metadata("10.1177/00491241211036161")
#' }
#'
#' @export
get_doi_metadata <- function(doi){

  url <- paste0("https://doi.org/", doi)

  res <- httr::GET(
    url,
    httr::add_headers(
      "Accept" = "application/vnd.citationstyles.csl+json"
    )
  )

  if (httr::status_code(res) != 200) {
    stop("DOI metadata not available")
  }

  txt <- httr::content(res, "text", encoding = "UTF-8")

  meta <- jsonlite::fromJSON(txt)

  authors <- paste(meta$author$given, meta$author$family)

  list(
    title = meta$title,
    journal = meta$`container-title`,
    year = meta$issued$`date-parts`[[1]][1],
    authors = authors
  )
}

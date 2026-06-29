#' Normalize a DOI
#'
#' Cleans and standardizes a DOI string so it can be used consistently
#' across package functions. The function removes common DOI URL prefixes
#' and trims whitespace.
#'
#' @param doi Character. A DOI string or DOI URL.
#'
#' @return A cleaned DOI string.
#'
#' @examples
#' normalize_doi("https://doi.org/10.1177/00491241211036161")
#'
#' @keywords internal
#' @export
normalize_doi <- function(doi){

  doi <- tolower(doi)
  doi <- gsub("^https?://doi.org/", "", doi)
  doi <- gsub("^doi:", "", doi)
  doi <- trimws(doi)

  doi
}

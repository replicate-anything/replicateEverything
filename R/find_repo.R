#' Find the repository for a paper replication
#'
#' Looks up the replication registry to determine which repository
#' contains the replication materials for a given DOI.
#'
#' @param doi Character. DOI of the paper.
#'
#' @return Character string containing the GitHub repository name.
#'
#' @examples
#' \dontrun{
#' find_repo("10.1177/00491241211036161")
#' }
#'
#' @keywords internal
#' @keywords internal
find_repo <- function(doi){

  doi <- normalize_doi(doi)

  index <- load_index()

  normalized_folders <- sapply(index$doi, normalize_doi)

  row <- index[normalized_folders == doi, ]

  if(nrow(row) == 0){
    stop("DOI not found in replication index")
  }

  repo <- row$repo[1]

  repo
}

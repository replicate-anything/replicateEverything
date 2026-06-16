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
#' @export
find_repo <- function(doi){

  doi <- normalize_doi(doi)

  index <- load_index()

  row <- index[index$doi == doi, ]

  if(nrow(row) == 0){
    stop("DOI not found in replication index")
  }

  repo <- row$repo[1]

  repo
}

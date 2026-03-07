#' Find replication repository
#'
#' Returns the GitHub repository that hosts replications for a paper.
#'
#' @param doi Character DOI of the paper.
#'
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

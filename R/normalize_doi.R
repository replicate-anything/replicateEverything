normalize_doi <- function(doi){

  doi <- tolower(doi)
  doi <- gsub("^https?://doi.org/", "", doi)
  doi <- gsub("^doi:", "", doi)
  doi <- trimws(doi)

  doi
}

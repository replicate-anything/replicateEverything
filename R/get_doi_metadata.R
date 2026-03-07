get_doi_metadata <- function(doi){

  library(httr)
  library(jsonlite)

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

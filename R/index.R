#' Load the replication registry index
#'
#' Downloads and reads the replication registry index file, which contains
#' metadata about all available paper replications.
#'
#' @return A data frame containing replication metadata including DOI,
#' title, authors, journal, and repository location.
#'
#' @examples
#' \dontrun{
#' load_index()
#' }
#'
#' @export
load_index <- function(){

  index_url <- "https://raw.githubusercontent.com/replicate-anything/registry/main/index.json"

  jsonlite::fromJSON(index_url)

}


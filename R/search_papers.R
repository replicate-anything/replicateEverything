#' Search papers in the replication registry
#'
#' Searches the registry index by keyword.
#'
#' @param query Character search term.
#'
#' @export
search_papers <- function(query){

  index <- load_index()

  subset(
    index,
    grepl(query, title, ignore.case = TRUE)
  )

}

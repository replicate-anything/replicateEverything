#' Search replicated papers
#'
#' Searches the replication registry for papers matching a keyword
#' in the title or author fields.
#'
#' @param query Character string used to search paper titles or authors.
#'
#' @return A filtered data frame of matching papers.
#'
#' @examples
#' \dontrun{
#' search_papers("causal")
#' }
#'
#' @export
search_papers <- function(query){

  index <- load_index()

  subset(
    index,
    grepl(query, title, ignore.case = TRUE)
  )

}

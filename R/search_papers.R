#' Search replicated papers
#'
#' Searches the replication registry for papers matching a keyword
#' in the title, handle, or author fields.
#'
#' @param query Character string used to search paper titles, handles, or authors.
#'
#' @return A filtered data frame of matching papers.
#'
#' @examples
#' \dontrun{
#' search_papers("causal")
#' search_papers("bounding-causes")
#' }
#'
#' @export
search_papers <- function(query) {
  index <- load_index()
  query <- as.character(query)

  match_title <- grepl(query, index$title, ignore.case = TRUE)
  match_handle <- if ("handle" %in% names(index)) {
    grepl(query, index$handle, ignore.case = TRUE)
  } else {
    rep(FALSE, nrow(index))
  }
  match_authors <- if ("authors" %in% names(index)) {
    grepl(query, index$authors, ignore.case = TRUE)
  } else {
    rep(FALSE, nrow(index))
  }

  index[match_title | match_handle | match_authors, , drop = FALSE]
}

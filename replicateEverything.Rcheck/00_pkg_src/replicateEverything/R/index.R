#' Load the replication registry index
#'
#' @return A data frame containing replication metadata.
#'
#' @examples
#' \dontrun{
#' head(load_index())
#' }
#'
#' @export
load_index <- function() {
  local_index <- getOption("replicateEverything.index", NULL)
  if (!is.null(local_index)) {
    return(local_index)
  }

  index_url <- "https://raw.githubusercontent.com/replicate-anything/registry/main/index.csv"
  utils::read.csv(index_url, stringsAsFactors = FALSE)
}

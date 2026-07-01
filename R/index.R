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

  registry_root <- auto_detect_registry_root()
  if (!is.null(registry_root)) {
    local_csv <- file.path(registry_root, "index.csv")
    if (file.exists(local_csv)) {
      return(utils::read.csv(local_csv, stringsAsFactors = FALSE))
    }
  }

  index_url <- "https://raw.githubusercontent.com/replicate-anything/registry/main/index.csv"
  utils::read.csv(index_url, stringsAsFactors = FALSE)
}

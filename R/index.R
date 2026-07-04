#' Load the replication registry index
#'
#' Returns `index.csv` from the configured registry root or from GitHub.
#' When the index has no `handle` column, one is derived from each row's
#' `folder` field.
#'
#' @return A data frame containing replication metadata (`folder`, `doi`,
#'   `title`, `journal`, `year`, `authors`, `repo`, and `handle` when present).
#'
#' @examples
#' \dontrun{
#' head(load_index()[, c("handle", "doi", "title")])
#' }
#'
#' @export
load_index <- function() {
  local_index <- getOption("replicateEverything.index", NULL)
  if (!is.null(local_index)) {
    return(ensure_index_handles(local_index))
  }

  registry_root <- auto_detect_registry_root()
  if (!is.null(registry_root)) {
    local_csv <- file.path(registry_root, "index.csv")
    if (file.exists(local_csv)) {
      return(ensure_index_handles(
        utils::read.csv(local_csv, stringsAsFactors = FALSE)
      ))
    }
  }

  index_url <- "https://raw.githubusercontent.com/replicate-anything/registry/main/index.csv"
  ensure_index_handles(utils::read.csv(index_url, stringsAsFactors = FALSE))
}

#' Ensure index rows expose a handle column
#' @keywords internal
ensure_index_handles <- function(index) {
  if (!is.data.frame(index) || nrow(index) == 0L) {
    return(index)
  }
  if (!"handle" %in% names(index)) {
    index$handle <- index$folder
  }
  index$handle <- as.character(index$handle)
  index$handle[!nzchar(index$handle)] <- index$folder[!nzchar(index$handle)]
  index
}

#' Resolve a registry handle to a DOI
#' @keywords internal
resolve_registry_handle <- function(x) {
  raw <- trimws(as.character(x))
  if (!nzchar(raw) || grepl("/", raw, fixed = TRUE)) {
    return(NULL)
  }
  if (grepl("^10\\.", raw)) {
    return(NULL)
  }
  idx <- load_index()
  if (!"handle" %in% names(idx)) {
    return(NULL)
  }
  hit <- idx[tolower(idx$handle) == tolower(raw), , drop = FALSE]
  if (nrow(hit) == 0L) {
    return(NULL)
  }
  normalize_doi(hit$doi[[1]])
}

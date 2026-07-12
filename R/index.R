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
      index <- ensure_index_handles(
        utils::read.csv(local_csv, stringsAsFactors = FALSE)
      )
      if (index_needs_stub_refresh(index)) {
        refreshed <- compile_registry_index_from_stubs(registry_root)
        if (
          !is.null(refreshed) &&
            nrow(refreshed) > 0L &&
            any(nzchar(refreshed$collections))
        ) {
          index <- refreshed
        }
      }
      return(index)
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
  for (col in c("collections", "maintainer_name", "maintainer_email", "languages")) {
    if (!col %in% names(index)) {
      index[[col]] <- ""
    }
    index[[col]] <- as.character(index[[col]])
    index[[col]][is.na(index[[col]])] <- ""
  }
  index
}

#' Compile index rows from registry study stubs (no write)
#' @keywords internal
compile_registry_index_from_stubs <- function(registry_root) {
  studies_dir <- registry_studies_dir(registry_root)
  if (!dir.exists(studies_dir)) {
    return(NULL)
  }
  yml_files <- list.files(studies_dir, pattern = "\\.yml$", full.names = TRUE)
  if (length(yml_files) == 0L) {
    return(NULL)
  }
  rows <- lapply(yml_files, function(path) {
    meta <- yaml::read_yaml(path)
    registry_index_row_from_meta(meta, study_root = NULL)
  })
  index <- do.call(rbind, rows)
  ensure_index_handles(index)
}

#' @keywords internal
index_needs_stub_refresh <- function(index) {
  if (!is.data.frame(index) || nrow(index) == 0L) {
    return(FALSE)
  }
  index <- ensure_index_handles(index)
  !any(nzchar(index$collections))
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
  doi_val <- hit$doi[[1]]
  if (is.null(doi_val) || !nzchar(trimws(as.character(doi_val)))) {
    return(as.character(hit$handle[[1]]))
  }
  normalize_doi(doi_val)
}

#' Compile registry index.csv from study stub yaml files
#'
#' Reads every `studies/*.yml` under a registry checkout and writes
#' `index.csv` with `collections`, `maintainer_*`, and `languages` taken from
#' each stub (no fetch from individual study repos).
#'
#' @param registry_root Path to the registry repository. Defaults to
#'   `getOption("replicateEverything.registry_root")` or [auto_detect_registry_root()].
#' @return Invisibly, a list with `index_path`, `index`, and `n`.
#'
#' @examples
#' \dontrun{
#' build_registry_index("../registry")
#' }
#'
#' @export
build_registry_index <- function(registry_root = NULL) {
  if (is.null(registry_root) || !nzchar(registry_root)) {
    registry_root <- getOption("replicateEverything.registry_root", NULL)
  }
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    registry_root <- auto_detect_registry_root()
  }
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    stop(
      "registry_root not found. Pass the path to the registry repository or set ",
      "options(replicateEverything.registry_root = ...).",
      call. = FALSE
    )
  }

  studies_dir <- registry_studies_dir(registry_root)
  yml_files <- list.files(studies_dir, pattern = "\\.yml$", full.names = TRUE)
  if (length(yml_files) == 0L) {
    stop("No study stubs found in ", studies_dir, call. = FALSE)
  }

  index <- compile_registry_index_from_stubs(registry_root)
  ord <- order(index$title, index$year, index$folder)
  index <- index[ord, , drop = FALSE]

  index_path <- file.path(registry_root, "index.csv")
  utils::write.csv(index, index_path, row.names = FALSE)

  invisible(list(
    index_path = index_path,
    index = index,
    n = nrow(index)
  ))
}

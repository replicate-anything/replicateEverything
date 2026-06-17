#' Resolve the registry folder name for a paper
#'
#' Uses the registry index \code{folder} column when available, otherwise
#' derives a path from the normalized DOI.
#'
#' @param doi Character. DOI of the paper.
#'
#' @return Character folder name under \code{papers/}.
#' @keywords internal
resolve_paper_path <- function(doi) {
  doi <- normalize_doi(doi)

  index <- tryCatch(load_index(), error = function(e) NULL)

  if (!is.null(index) && "folder" %in% names(index) && "doi" %in% names(index)) {
    normalized_index_dois <- vapply(index$doi, normalize_doi, character(1))
    row <- index[normalized_index_dois == doi, , drop = FALSE]
    if (nrow(row) > 0 && nzchar(row$folder[[1]])) {
      return(row$folder[[1]])
    }
  }

  gsub("/", "_", doi)
}

#' Build base URLs and paths for a paper in the registry
#'
#' @param doi Character. DOI of the paper.
#' @param repo Optional repository slug. Defaults to \code{find_repo(doi)}.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return A list with \code{repo}, \code{folder}, \code{base_url}, and
#'   optional \code{local_root}.
#' @keywords internal
paper_context <- function(doi, repo = NULL, folder = NULL) {
  doi <- normalize_doi(doi)
  if (is.null(folder) || !nzchar(folder)) {
    folder <- resolve_paper_path(doi)
  }

  if (is.null(repo) || !nzchar(repo)) {
    repo <- tryCatch(
      find_repo(doi),
      error = function(e) "replicate-anything/registry"
    )
  }

  registry_root <- getOption("replicateEverything.registry_root", NULL)
  local_root <- if (!is.null(registry_root)) {
    file.path(registry_root, "papers", folder)
  } else {
    NULL
  }

  base_url <- paste0(
    "https://raw.githubusercontent.com/",
    repo,
    "/main/papers/",
    folder
  )

  list(
    doi = doi,
    repo = repo,
    folder = folder,
    base_url = base_url,
    local_root = local_root
  )
}

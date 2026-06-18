#' Resolve the expected artifact path for a replication entry
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @param what Replication identifier.
#' @keywords internal
default_artifact_path <- function(rep, what) {
  if (identical(rep$type, "figure")) {
    return(paste0("artifacts/", what, ".png"))
  }
  paste0("artifacts/", what, ".html")
}

#' Get the local artifact file path for a replication, if available
#'
#' @inheritParams render_replication
#' @return Character path or \code{NULL}.
#' @keywords internal
local_artifact_path <- function(doi, what, repo = NULL) {
  meta <- get_replication_meta(doi, repo = repo)
  rep <- find_replication_entry(meta, what)
  ctx <- paper_context(doi, repo = repo)

  if (is.null(ctx$local_root)) {
    return(NULL)
  }

  artifact <- rep$artifact
  if (is.null(artifact) || !nzchar(artifact)) {
    artifact <- default_artifact_path(rep, what)
  }

  file.path(ctx$local_root, artifact)
}

#' Check whether a precomputed artifact is available
#'
#' @inheritParams render_replication
#' @return Logical scalar.
#' @export
artifact_available <- function(doi, what, repo = NULL) {
  local_path <- local_artifact_path(doi, what, repo = repo)
  if (!is.null(local_path)) {
    return(file.exists(local_path))
  }

  path <- get_artifact_path(doi, what, repo = repo)
  if (is.null(path)) {
    return(FALSE)
  }

  !is.null(suppressWarnings(tryCatch(
    load_artifact(doi, what, repo = repo),
    error = function(e) NULL
  )))
}

#' Validate that a precomputed artifact exists
#'
#' @inheritParams render_replication
#' @return Invisibly \code{TRUE} on success.
#' @export
validate_artifact <- function(doi, what, repo = NULL) {
  local_path <- local_artifact_path(doi, what, repo = repo)
  if (!is.null(local_path) && !file.exists(local_path)) {
    stop(
      "Missing artifact file: ", local_path,
      ". Run scripts/build_artifacts.R in the registry.",
      call. = FALSE
    )
  }

  if (!artifact_available(doi, what, repo = repo)) {
    stop(
      "Artifact not available for replication ", what, ".",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Validate all artifacts for a paper
#'
#' @param doi Character. DOI of the paper.
#' @param repo Optional repository slug.
#' @return Invisibly \code{TRUE} if every replication has an artifact.
#' @export
validate_paper_artifacts <- function(doi, repo = NULL) {
  meta <- get_replication_meta(doi, repo = repo)
  missing <- character(0)

  for (rep in meta$replications) {
    ok <- tryCatch({
      validate_artifact(doi, rep$id, repo = repo)
      TRUE
    }, error = function(e) {
      missing <<- c(missing, paste0(rep$id, ": ", conditionMessage(e)))
      FALSE
    })
  }

  if (length(missing) > 0) {
    stop(
      "Missing artifacts for ", doi, ":\n",
      paste0(" - ", missing, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

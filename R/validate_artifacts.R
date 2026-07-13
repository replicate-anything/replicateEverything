#' Resolve the expected artifact path for a replication entry
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @param what Replication identifier.
#' @keywords internal
default_artifact_path <- function(rep, what) {
  if (identical(rep$type, "figure")) {
    return(paste0("outputs/", what, ".png"))
  }
  if (format_specified(rep)) {
    return(paste0("outputs/", what, ".html"))
  }
  paste0("outputs/", what, ".html")
}

#' Get the local artifact file path for a replication, if available
#'
#' @inheritParams render_replication
#' @return Character path or \code{NULL}.
#' @keywords internal
local_artifact_path <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  if (is_package_replication(meta)) {
    return(NULL)
  }

  rep <- find_replication_entry(meta, what, language = language)
  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (is.null(ctx$local_root)) {
    return(NULL)
  }

  for (rel in study_artifact_rel_candidates(rep)) {
    local <- file.path(ctx$local_root, rel)
    if (file.exists(local)) {
      return(local)
    }
  }
  NULL
}

#' Check whether a precomputed artifact is available
#'
#' @inheritParams render_replication
#' @return Logical scalar.
#'
#' @examples
#' \dontrun{
#' artifact_available("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
artifact_available <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  local_path <- local_artifact_path(doi, what, repo = repo, folder = folder, language = language)
  if (!is.null(local_path)) {
    return(file.exists(local_path))
  }

  path <- get_artifact_path(doi, what, repo = repo, language = language)
  if (is.null(path)) {
    return(FALSE)
  }

  !is.null(suppressWarnings(tryCatch(
    load_artifact(doi, what, repo = repo, folder = folder, language = language),
    error = function(e) NULL
  )))
}

#' Validate that a precomputed artifact exists
#'
#' @inheritParams render_replication
#' @return Invisibly \code{TRUE} on success.
#'
#' @examples
#' \dontrun{
#' validate_artifact("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
validate_artifact <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    if (!artifact_available(doi, what, repo = repo, folder = folder, language = language)) {
      pkg <- as.character(meta$paper$package[[1]])
      stop(
        "Artifact not available for replication ", what,
        ". Run ", study_build_function("package"), "(",
        shQuote(pkg, type = "sh"), ", install_deps = TRUE).",
        call. = FALSE
      )
    }
    return(invisible(TRUE))
  }

  local_path <- local_artifact_path(doi, what, repo = repo, language = language)
  if (!is.null(local_path) && file.exists(local_path)) {
    return(invisible(TRUE))
  }
  if (!is.null(local_path) && !file.exists(local_path)) {
    ctx <- tryCatch(paper_context(doi, repo = repo, folder = folder), error = function(e) NULL)
    hint <- if (!is.null(ctx) && isTRUE(ctx$is_folder_study)) {
      ". Run build_study_outputs() in the study repository."
    } else {
      ". Run scripts/build_artifacts.R in the registry."
    }
    stop(
      "Missing artifact file: ", local_path,
      hint,
      call. = FALSE
    )
  }

  if (!artifact_available(doi, what, repo = repo, language = language)) {
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
#'
#' @examples
#' \dontrun{
#' validate_paper_artifacts("10.1177/00491241211036161")
#' }
#'
#' @keywords internal
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

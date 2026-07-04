#' Whether display content is missing or empty
#'
#' Used by Shiny and other UIs to decide whether to fall back to a live run.
#'
#' @param x Artifact or display value.
#' @return Logical scalar.
#' @keywords internal
artifact_display_missing <- function(x) {
  artifact_content_missing(x)
}

#' Resolve a replication result envelope to a display-ready value
#'
#' Accepts a precomputed artifact, a \code{render_for_display()} result, or a
#' raw analysis object. Applies \code{format_for_display()} when needed.
#'
#' @param doi Character. DOI of the paper.
#' @param what Replication identifier.
#' @param result Artifact HTML/path, replication result list, or analysis object.
#' @param install_deps Logical. Passed to \code{format_for_display()}.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name.
#' @return Display-ready value (HTML string, ggplot, path, etc.) or an error.
#' @keywords internal
resolve_display_value <- function(
  doi,
  what,
  result,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
) {
  if (inherits(result, "error")) {
    return(result)
  }
  if (is.list(result) && !is.null(result$display)) {
    return(result$display)
  }
  if (is.list(result) && identical(result$source, "package")) {
    return(replication_object(result))
  }
  if (is.character(result) && length(result) == 1L && nzchar(result) && file.exists(result)) {
    return(result)
  }
  if (
    is.character(result) &&
      length(result) == 1L &&
      grepl("<table|<html|<!DOCTYPE|<pre", result, ignore.case = TRUE)
  ) {
    return(result)
  }

  analysis <- if (is.list(result) && !is.null(result$object)) {
    replication_object(result)
  } else {
    result
  }
  if (artifact_display_missing(analysis)) {
    return(NULL)
  }

  tryCatch(
    format_for_display(
      analysis,
      doi,
      what,
      language = language,
      install_deps = install_deps,
      repo = repo,
      folder = folder
    ),
    error = function(e) e
  )
}

#' Load or run a replication for display
#'
#' Centralizes artifact-vs-live logic for Shiny and other front ends.
#'
#' @param doi Character. DOI of the paper.
#' @param what Replication identifier.
#' @param prefer Character. \code{"artifact"} tries the precomputed file first;
#'   \code{"live"} runs the replication; \code{"auto"} is an alias for
#'   \code{"artifact"} with \code{fallback_live = TRUE}.
#' @param fallback_live When \code{TRUE} and the artifact is missing, run live.
#' @param install_deps Logical. Passed to live rendering.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name.
#' @return A list with \code{ok}, \code{value}, \code{source} (\code{"artifact"}
#'   or \code{"live"}), and optional \code{error} or \code{missing}.
#' @keywords internal
load_replication_for_display <- function(
  doi,
  what,
  language = NULL,
  prefer = c("auto", "artifact", "live"),
  fallback_live = TRUE,
  install_deps = TRUE,
  repo = NULL,
  folder = NULL
) {
  prefer <- match.arg(prefer)
  if (identical(prefer, "auto")) {
    prefer <- "artifact"
  }

  if (identical(prefer, "live")) {
    return(run_live_display(
      doi, what,
      language = language,
      install_deps = install_deps,
      repo = repo,
      folder = folder
    ))
  }

  artifact <- tryCatch(
    load_artifact(doi, what, repo = repo, folder = folder, language = language),
    error = function(e) e
  )
  if (inherits(artifact, "error")) {
    return(list(ok = FALSE, error = artifact, source = "artifact"))
  }
  if (!artifact_display_missing(artifact)) {
    return(list(
      ok = TRUE,
      value = artifact,
      source = "artifact",
      raw = artifact
    ))
  }

  if (isTRUE(fallback_live)) {
    return(run_live_display(
      doi, what,
      language = language,
      install_deps = install_deps,
      repo = repo,
      folder = folder
    ))
  }

  list(ok = FALSE, missing = TRUE, source = "artifact")
}

#' @keywords internal
run_live_display <- function(
  doi,
  what,
  language = NULL,
  install_deps = TRUE,
  repo = NULL,
  folder = NULL
) {
  result <- try_render_for_display(
    doi,
    what,
    language = language,
    install_deps = install_deps,
    repo = repo,
    folder = folder
  )
  if (inherits(result, "error")) {
    return(list(ok = FALSE, error = result, source = "live"))
  }
  value <- resolve_display_value(
    doi,
    what,
    result,
    language = language,
    install_deps = install_deps,
    repo = repo,
    folder = folder
  )
  if (inherits(value, "error")) {
    return(list(ok = FALSE, error = value, source = "live"))
  }
  if (artifact_display_missing(value)) {
    return(list(ok = FALSE, missing = TRUE, source = "live"))
  }
  list(ok = TRUE, value = value, source = "live", raw = result)
}

#' Resolve display output for an already-selected result
#'
#' @inheritParams resolve_display_value
#' @param source Character. \code{"artifact"} or \code{"live"}.
#' @return A list with \code{ok}, \code{value}, and optional \code{error} or
#'   \code{missing}.
#' @keywords internal
resolve_replication_display <- function(
  doi,
  what,
  result,
  language = NULL,
  source = c("artifact", "live"),
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
) {
  source <- match.arg(source)
  if (inherits(result, "error")) {
    return(list(ok = FALSE, error = result))
  }
  if (artifact_display_missing(result)) {
    return(list(ok = FALSE, missing = TRUE))
  }
  value <- resolve_display_value(
    doi,
    what,
    result,
    language = language,
    install_deps = identical(source, "live"),
    repo = repo,
    folder = folder
  )
  if (inherits(value, "error")) {
    return(list(ok = FALSE, error = value))
  }
  if (artifact_display_missing(value)) {
    return(list(ok = FALSE, missing = TRUE))
  }
  list(ok = TRUE, value = value)
}

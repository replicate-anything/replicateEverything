#' Format a replication error for user-facing display
#'
#' Unwraps \code{conditionMessage()} and, when present, parent errors and the
#' call that failed.
#'
#' @param x An error condition or character message.
#' @return A single character string suitable for logs or UI.
#'
#' @examples
#' \dontrun{
#' err <- simpleError("Replication failed", call = quote(run_replication()))
#' replication_error_message(err)
#' }
#'
#' @keywords internal
strip_ansi_escapes <- function(x) {
  if (!is.character(x) || !length(x)) {
    return(x)
  }
  tryCatch({
    x <- gsub("\x1b\\[[0-9;]*m", "", x, perl = TRUE)
    gsub("\x1b\\]8;[^\x1b]*\x1b\\\\", "", x, perl = TRUE)
  }, error = function(e) {
    gsub("\x1b", "", x, fixed = TRUE)
  })
}

replication_error_message <- function(x) {
  if (inherits(x, "study_package_error")) {
    return(strip_ansi_escapes(conditionMessage(x)))
  }
  if (is.character(x)) {
    return(strip_ansi_escapes(paste(x, collapse = "\n")))
  }
  if (!inherits(x, "condition")) {
    return(as.character(x))
  }

  parts <- c(conditionMessage(x))

  parent <- x$parent
  if (!is.null(parent) && inherits(parent, "condition")) {
    parts <- c(parts, paste0("Caused by: ", conditionMessage(parent)))
  }

  call <- conditionCall(x)
  if (!is.null(call) && inherits(x, "error")) {
    parts <- c(
      parts,
      paste0("Call: ", paste(deparse(call, nlines = 1, width.cutoff = 120L), collapse = ""))
    )
  }

  strip_ansi_escapes(paste(parts, collapse = "\n\n"))
}

#' Run a replication and return a result or error object
#'
#' Like \code{\link{render_for_display}} but never throws; failures are
#' returned as \code{simpleError} objects.
#'
#' @inheritParams render_for_display
#' @return A replication result list, a display-ready object, or an error.
#'
#' @examples
#' \dontrun{
#' try_render_for_display("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
try_render_for_display <- function(
  doi,
  what,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
) {
  tryCatch(
    render_for_display(
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

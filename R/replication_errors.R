#' Format a replication error for user-facing display
#'
#' Unwraps \code{conditionMessage()} and, when present, parent errors and the
#' call that failed.
#'
#' @param x An error condition or character message.
#' @return A single character string suitable for logs or UI.
#'
#' @examples
#' err <- simpleError("Replication failed", call = quote(run_replication()))
#' replication_error_message(err)
#'
#' @export
replication_error_message <- function(x) {
  if (inherits(x, "study_package_error")) {
    return(conditionMessage(x))
  }
  if (is.character(x)) {
    return(paste(x, collapse = "\n"))
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

  paste(parts, collapse = "\n\n")
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
#' @export
try_render_for_display <- function(doi, what, install_deps = FALSE, repo = NULL, folder = NULL) {
  tryCatch(
    render_for_display(
      doi,
      what,
      install_deps = install_deps,
      repo = repo,
      folder = folder
    ),
    error = function(e) e
  )
}

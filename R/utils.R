#' @importFrom utils read.csv write.csv download.file
NULL

#' Null-coalescing infix (also treats scalar NA as missing)
#' @keywords internal
`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
}

#' Report progress to UIs (Shiny) and the R console
#'
#' Invokes \code{getOption("replicateEverything.progress")} when set, and also
#' emits a \code{message()} so console users see the same text.
#'
#' @param msg Character status line.
#' @keywords internal
replicate_progress <- function(msg) {
  if (is.null(msg) || !nzchar(as.character(msg))) {
    return(invisible(NULL))
  }
  msg <- as.character(msg)
  cb <- getOption("replicateEverything.progress", NULL)
  if (is.function(cb)) {
    tryCatch(cb(msg), error = function(e) NULL)
  }
  message(msg)
  invisible(NULL)
}

#' Whether replication runs may install missing dependencies
#'
#' Live Run and Shiny verify only. Maintainer builds set
#' \code{options(replicateEverything.install_dependencies = TRUE)} (as
#' \code{build_study_outputs(install_deps = TRUE)} does).
#'
#' @param want Caller requested \code{install_deps = TRUE}.
#' @return Logical scalar.
#' @keywords internal
allow_dependency_install <- function(want = FALSE) {
  isTRUE(want) &&
    isTRUE(getOption("replicateEverything.install_dependencies", FALSE))
}

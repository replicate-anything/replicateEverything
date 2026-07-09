#' @importFrom utils read.csv write.csv download.file
NULL

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

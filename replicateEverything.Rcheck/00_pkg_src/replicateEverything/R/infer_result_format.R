#' Infer the format of a replication result object
#'
#' @param object Result returned by a replication script.
#' @param type Replication type (\code{figure} or \code{table}).
#'
#' @return Character string describing the result format.
#' @keywords internal
infer_result_format <- function(object, type) {
  if (inherits(object, "ggplot")) {
    return("ggplot")
  }

  if (is.list(object) && !is.data.frame(object)) {
    return("rds")
  }

  if (is.data.frame(object) || is.matrix(object)) {
    return("data.frame")
  }

  if (is.character(object) && length(object) == 1 &&
      grepl("^\\s*<", object)) {
    return("html")
  }

  if (inherits(object, "html")) {
    return("html")
  }

  if (type == "figure") {
    return("plot")
  }

  "unknown"
}

#' Extract a plain object from a replication result envelope
#'
#' @param x A replication result list or raw object.
#' @return The underlying replication object.
#'
#' @examples
#' result <- list(id = "fig_1", object = data.frame(x = 1), class = "replication_result")
#' replication_object(result)
#'
#' @export
replication_object <- function(x) {
  if (is.list(x) && !is.null(x$object)) {
    return(x$object)
  }
  x
}

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

  if (inherits(object, "stata_replication_result")) {
    path <- object$output_path %||% object$smcl_path %||% NULL
    if (!is.null(path) && stata_output_is_image(path)) {
      return("png")
    }
    return("stata_output")
  }

  if (inherits(object, "python_replication_result")) {
    path <- object$output_path %||% NULL
    if (!is.null(path) && grepl("\\.(png|jpg|jpeg|gif|svg|pdf)$", path, ignore.case = TRUE)) {
      return("png")
    }
    if (!is.null(object$preview)) {
      return("data.frame")
    }
    return("text")
  }

  if (inherits(object, "prep_output_preview")) {
    path <- object$path %||% NULL
    if (!is.null(path) && nzchar(path) && file.exists(path)) {
      if (grepl("\\.(png|jpg|jpeg|gif|svg|pdf)$", path, ignore.case = TRUE)) {
        return("png")
      }
    }
    return("unknown")
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
#' \dontrun{
#' result <- list(id = "fig_1", object = data.frame(x = 1), class = "replication_result")
#' replication_object(result)
#' }
#'
#' @keywords internal
replication_object <- function(x) {
  if (inherits(x, "stata_replication_result")) {
    path <- x$output_path %||% x$smcl_path %||% NULL
    if (!is.null(path) && stata_output_is_image(path)) {
      return(path)
    }
    return(x)
  }
  if (inherits(x, "python_replication_result")) {
    path <- x$output_path %||% NULL
    if (!is.null(path) && file.exists(path) &&
        grepl("\\.(png|jpg|jpeg|gif|svg|pdf)$", path, ignore.case = TRUE)) {
      return(path)
    }
    return(x)
  }
  if (inherits(x, "prep_output_preview")) {
    path <- x$path %||% NULL
    if (!is.null(path) && nzchar(path) && file.exists(path) &&
        grepl("\\.(png|jpg|jpeg|gif|svg|pdf)$", path, ignore.case = TRUE)) {
      return(path)
    }
    return(x)
  }
  if (is.list(x) && !is.null(x$object)) {
    obj <- x$object
    if (inherits(obj, "stata_replication_result")) {
      path <- obj$output_path %||% obj$smcl_path %||% NULL
      if (!is.null(path) && stata_output_is_image(path)) {
        return(path)
      }
    }
    if (inherits(obj, "python_replication_result")) {
      path <- obj$output_path %||% NULL
      if (!is.null(path) && file.exists(path) &&
          grepl("\\.(png|jpg|jpeg|gif|svg|pdf)$", path, ignore.case = TRUE)) {
        return(path)
      }
    }
    return(obj)
  }
  x
}

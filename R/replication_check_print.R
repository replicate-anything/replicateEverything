#' Print a replication checklist result
#'
#' @param x Result from [check_replication()], [check_and_bake_study()], or
#'   [register_study()].
#' @param ... Ignored.
#' @keywords internal
#' @exportS3Method print package_replication_check
print.package_replication_check <- function(x, ...) {
  print_replication_check(x, label = "package")
  invisible(x)
}

#' @rdname print.package_replication_check
#' @exportS3Method print folder_replication_check
print.folder_replication_check <- function(x, ...) {
  print_replication_check(x, label = "folder")
  invisible(x)
}

#' @rdname print.package_replication_check
#' @exportS3Method print replication_check
print.replication_check <- function(x, ...) {
  label <- if (inherits(x, "folder_replication_check")) "folder" else "package"
  print_replication_check(x, label = label)
  invisible(x)
}

#' @keywords internal
print_replication_check <- function(x, label = "study") {
  if (!is.data.frame(x$checks)) {
    print(unclass(x))
    return(invisible(x))
  }
  cat(if (isTRUE(x$ok)) "PASS" else "FAIL", " - ", label, " replication checklist\n", sep = "")
  path <- x$study_path %||% x$package_path %||% NA_character_
  if (!is.null(path) && length(path) == 1L && !is.na(path) && nzchar(path)) {
    cat("Location:", path, "\n")
  }
  for (i in seq_len(nrow(x$checks))) {
    mark <- if (isTRUE(x$checks$passed[i])) "[ok]" else "[x]"
    cat(" ", mark, " ", x$checks$check[i], ": ", x$checks$message[i], "\n", sep = "")
  }
  invisible(x)
}

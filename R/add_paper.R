#' Add a package-backed study to the replication registry (maintainer)
#'
#' Validates a study replication package with [check_package_replication()],
#' ensures registry handoff files exist (via [write_study_registry_stub()] when
#' missing), then installs the stub in a registry checkout via
#' [sync_study_to_registry()].
#'
#' Contributors should run [prepare_study_for_registry()] and open a pull request.
#' Maintainers use this function from a local registry checkout.
#'
#' Package-backed studies do **not** copy code, data, or artifacts into the
#' registry. Those live in the study package (`inst/report/artifacts/` from
#' `build_report()`).
#'
#' @param location Local package path or GitHub address (`org/repo` or URL).
#' @param full_replication If `TRUE`, also run every table and figure live.
#' @param registry_root Path to the registry repository root (contains
#'   `studies/` and `index.csv`). Defaults to
#'   `getOption("replicateEverything.registry_root")`.
#' @param dry_run If `TRUE`, run checks only; do not write registry files.
#' @param audit If `TRUE`, run [audit_everything()] for this study after sync.
#' @return Invisibly, the result of [check_package_replication()], with
#'   `stub_path` and `index_updated` when registration succeeds.
#' @keywords internal
add_paper <- function(
  location,
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE,
  audit = FALSE
) {
  result <- check_package_replication(location, full_replication = full_replication)

  if (!isTRUE(result$ok)) {
    message("Package validation failed:")
    failed <- result$checks[!result$checks$passed, , drop = FALSE]
    for (i in seq_len(nrow(failed))) {
      message("  [FAIL] ", failed$check[i], ": ", failed$message[i])
    }
    message(
      "\nSee vignette('package-replication-checklist', package = 'replicateEverything') ",
      "for requirements."
    )
    return(invisible(result))
  }

  message("All checks passed (", nrow(result$checks), " items).")

  if (isTRUE(dry_run)) {
    message("dry_run = TRUE: registry not modified.")
    return(invisible(result))
  }

  study_root <- result$package_path
  paths <- study_registry_handoff_paths(study_root, kind = "package")
  if (!file.exists(paths$stub_path)) {
    write_study_registry_stub(study_root)
  }

  synced <- sync_study_to_registry(
    study_root,
    registry_root = registry_root,
    audit = audit
  )

  result$stub_path <- synced$stub_path
  result$index_updated <- synced$index_updated
  result$folder <- synced$folder
  result$registry_stub_path <- paths$stub_path
  result$registry_index_path <- paths$index_path
  invisible(structure(result, class = c("package_replication_check", "list")))
}

#' Print a replication checklist result
#'
#' @param x Result from [check_package_replication()], [check_folder_replication()],
#'   [add_paper()], or [add_folder_paper()].
#' @param ... Ignored.
#' @keywords internal
#' @export
print.package_replication_check <- function(x, ...) {
  print_replication_check(x, label = "package")
  invisible(x)
}

#' @rdname print.package_replication_check
#' @keywords internal
#' @export
print.folder_replication_check <- function(x, ...) {
  print_replication_check(x, label = "folder")
  invisible(x)
}

#' @rdname print.package_replication_check
#' @keywords internal
#' @export
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

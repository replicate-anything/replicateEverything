#' Add a package-backed study to the replication registry
#'
#' Validates a study replication package with [check_package_replication()],
#' then writes a lightweight registry stub (`studies/<folder>.yml`)
#' and updates `index.csv`.
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
#' @return Invisibly, the result of [check_package_replication()], with
#'   `stub_path` and `index_updated` when registration succeeds.
#' @keywords internal
add_paper <- function(
  location,
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE
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

  if (is.null(registry_root) || !nzchar(registry_root)) {
    registry_root <- getOption("replicateEverything.registry_root", NULL)
  }
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    stop(
      "registry_root not found. Pass the path to the registry repository or set ",
      "options(replicateEverything.registry_root = ...).",
      call. = FALSE
    )
  }

  meta <- result$meta
  paper <- meta$paper
  folder <- doi_to_registry_folder(paper$doi)
  package_folder <- basename(result$package_path)
  stub <- registry_stub_from_package_meta(meta, package_folder = package_folder)

  studies_dir <- registry_studies_dir(registry_root)
  dir.create(studies_dir, recursive = TRUE, showWarnings = FALSE)
  stub_path <- file.path(studies_dir, paste0(folder, ".yml"))
  stub_yaml <- yaml::as.yaml(stub)
  header <- c(
    "# Lightweight registry stub for a package-backed study.",
    paste0("# Registry folder: ", folder),
    ""
  )
  writeLines(c(header, stub_yaml), stub_path, useBytes = TRUE)
  legacy_dir <- file.path(studies_dir, folder)
  if (dir.exists(legacy_dir)) {
    unlink(legacy_dir, recursive = TRUE)
  }

  index_path <- file.path(registry_root, "index.csv")
  authors <- paper$authors %||% ""
  if (length(authors) > 1) {
    authors <- paste(authors, collapse = ", ")
  } else {
    authors <- as.character(authors[[1]] %||% "")
  }
  row <- data.frame(
    folder = folder,
    doi = normalize_doi(paper$doi),
    title = as.character(paper$title[[1]]),
    journal = as.character(paper$journal %||% ""),
    year = as.integer(paper$year %||% NA_integer_),
    authors = authors,
    repo = as.character((meta$repo %||% paper$package_repo)[[1]]),
    stringsAsFactors = FALSE
  )
  if (file.exists(index_path)) {
    index <- utils::read.csv(index_path, stringsAsFactors = FALSE)
    index <- index[normalize_doi(index$doi) != row$doi, , drop = FALSE]
    index <- rbind(index, row)
  } else {
    index <- row
  }
  utils::write.csv(index, index_path, row.names = FALSE)

  message("Wrote registry stub: ", stub_path)
  message("Updated index: ", index_path)

  result$stub_path <- stub_path
  result$index_updated <- index_path
  result$folder <- folder
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

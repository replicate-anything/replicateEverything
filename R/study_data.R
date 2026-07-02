#' Roots to search for external study data files
#'
#' Checks \code{replicateEverything.study_data_root},
#' \code{replicateEverything.study_data_roots}, \code{replicate_shiny.app_root},
#' and \code{getwd()} (typically the Shiny app directory).
#'
#' @param ctx Optional paper context.
#' @return Character vector of existing directory paths.
#' @keywords internal
study_data_search_roots <- function(ctx = NULL) {
  roots <- c(
    getOption("replicateEverything.study_data_root", NULL),
    unlist(getOption("replicateEverything.study_data_roots", NULL), use.names = FALSE),
    getOption("replicate_shiny.app_root", NULL)
  )
  if (!is.null(ctx) && is.list(ctx) && !is.null(ctx$study_data_root)) {
    roots <- c(ctx$study_data_root, roots)
  }
  roots <- c(roots, getwd())
  roots <- unique(as.character(roots))
  roots <- roots[!is.na(roots) & nzchar(roots)]
  roots <- roots[dir.exists(roots)]
  if (length(roots) == 0L) {
    return(character(0))
  }
  vapply(roots, function(path) {
    normalizePath(path, winslash = "/", mustWork = FALSE)
  }, character(1))
}

#' Study subfolder names used under external data roots
#'
#' @inheritParams study_data_search_roots
#' @param meta Parsed replication metadata.
#' @keywords internal
study_data_folder_names <- function(meta, ctx = NULL) {
  study_folder_map_keys(meta, ctx)
}

#' Candidate paths for a replication data file
#'
#' @param rel_path Path relative to study root (e.g. \code{data/file.dta}).
#' @param study_root Normalized study repository root.
#' @inheritParams study_data_folder_names
#' @return Character vector of paths checked (deduplicated, in search order).
#' @keywords internal
study_data_file_candidates <- function(rel_path, study_root, meta, ctx = NULL) {
  rel_path <- gsub("\\", "/", as.character(rel_path), fixed = TRUE)
  file_name <- basename(rel_path)

  checked <- c(
    file.path(study_root, rel_path),
    file.path(study_root, "data", file_name)
  )

  for (root in study_data_search_roots(ctx)) {
    for (name in study_data_folder_names(meta, ctx)) {
      checked <- c(
        checked,
        file.path(root, "data", name, file_name),
        file.path(root, "data", name, rel_path),
        file.path(root, name, file_name),
        file.path(root, name, rel_path)
      )
    }
  }

  unique(checked)
}

#' Resolve a study data file on disk
#'
#' @inheritParams study_data_file_candidates
#' @return List with \code{found}, \code{path}, and \code{checked}.
#' @keywords internal
resolve_study_data_file <- function(rel_path, study_root, meta, ctx = NULL) {
  checked <- study_data_file_candidates(rel_path, study_root, meta, ctx)
  for (candidate in checked) {
    if (file.exists(candidate)) {
      return(list(
        found = TRUE,
        path = normalizePath(candidate, winslash = "/", mustWork = FALSE),
        checked = checked
      ))
    }
  }
  list(found = FALSE, path = NULL, checked = checked)
}

#' Link or copy a data file into the study tree for Stata
#'
#' @param from Source file path.
#' @param to Target path under \code{study_root}.
#' @keywords internal
link_or_copy_study_data_file <- function(from, to) {
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  from <- normalizePath(from, winslash = "/", mustWork = FALSE)
  to <- normalizePath(to, winslash = "/", mustWork = FALSE)
  if (file.exists(to)) {
    if (identical(from, to)) {
      return(invisible(to))
    }
    unlink(to)
  }
  if (.Platform$OS.type == "windows") {
    if (isTRUE(tryCatch(file.link(from, to), error = function(e) FALSE))) {
      return(invisible(to))
    }
  } else if (isTRUE(tryCatch(file.symlink(from, to), error = function(e) FALSE))) {
    return(invisible(to))
  }
  if (!isTRUE(file.copy(from, to, overwrite = TRUE))) {
    stop("Failed to copy data file to ", to, call. = FALSE)
  }
  invisible(to)
}

#' Format an error when a study data file cannot be located
#'
#' @inheritParams resolve_study_data_file
#' @keywords internal
study_data_not_found_message <- function(rel_path, study_root, checked, meta, ctx = NULL) {
  roots <- study_data_search_roots(ctx)
  names <- study_data_folder_names(meta, ctx)
  paste0(
    "Data file not found: ", rel_path, "\n",
    "Study folder: ", study_root, "\n",
    if (length(roots) > 0L) {
      paste0(
        "External data roots: ",
        paste(roots, collapse = ", "),
        "\n"
      )
    } else {
      ""
    },
    if (length(names) > 0L) {
      paste0(
        "Study data subfolders tried: ",
        paste(names, collapse = ", "),
        "\n"
      )
    } else {
      ""
    },
    "Searched:\n",
    paste0("  - ", checked, collapse = "\n"),
    "\n\nPlace data in study_root/data/ or beside the Shiny app at ",
    "data/<study>/ (e.g. data/rep-<doi>/). ",
    "Set options(replicateEverything.study_data_root = '<app-dir>') if needed."
  )
}

#' Ensure replication data files exist under a study root
#'
#' Looks in the study checkout first, then external roots such as
#' \code{<app>/data/rep-<doi>/}. When found externally, links or copies into
#' \code{study_root} so Stata paths keep working.
#'
#' @param data_files Character vector of paths relative to study root.
#' @param study_root Normalized study repository root.
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @return Invisibly, character vector of resolved paths under \code{study_root}.
#' @keywords internal
ensure_study_data_files <- function(data_files, study_root, meta, ctx = NULL) {
  if (is.null(data_files)) {
    return(invisible(character(0)))
  }
  if (is.list(data_files)) {
    data_files <- unlist(data_files, use.names = FALSE)
  }
  data_files <- as.character(data_files)
  data_files <- data_files[nzchar(data_files)]
  if (length(data_files) == 0L) {
    return(invisible(character(0)))
  }

  resolved_paths <- vapply(data_files, function(rel_path) {
    target <- file.path(study_root, rel_path)
    hit <- resolve_study_data_file(rel_path, study_root, meta, ctx)
    if (!isTRUE(hit$found)) {
      stop(
        study_data_not_found_message(rel_path, study_root, hit$checked, meta, ctx),
        call. = FALSE
      )
    }
    if (!identical(
      normalizePath(hit$path, winslash = "/", mustWork = FALSE),
      normalizePath(target, winslash = "/", mustWork = FALSE)
    )) {
      link_or_copy_study_data_file(hit$path, target)
    }
    normalizePath(target, winslash = "/", mustWork = FALSE)
  }, character(1))

  invisible(resolved_paths)
}

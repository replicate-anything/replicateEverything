#' Root directory for external study data
#'
#' Uses \code{ctx$study_data_root}, then
#' \code{getOption("replicateEverything.study_data_root")}, then \code{getwd()}.
#'
#' @param ctx Optional paper context.
#' @return Normalized path.
#' @keywords internal
study_data_root <- function(ctx = NULL) {
  root <- NULL
  if (!is.null(ctx) && is.list(ctx) && !is.null(ctx$study_data_root)) {
    root <- as.character(ctx$study_data_root[[1]] %||% ctx$study_data_root)
  }
  if (is.null(root) || !nzchar(root)) {
    root <- getOption("replicateEverything.study_data_root", NULL)
  }
  if (is.null(root) || !nzchar(root)) {
    root <- getwd()
  }
  normalizePath(root, winslash = "/", mustWork = FALSE)
}

#' Study subfolder name under \code{data/}
#'
#' @param meta Parsed replication metadata.
#' @param ctx Optional paper context.
#' @return Character scalar.
#' @keywords internal
study_data_folder_name <- function(meta, ctx = NULL) {
  names <- study_folder_map_keys(meta, ctx)
  rep_like <- names[grepl("^rep-", names)]
  if (length(rep_like) > 0L) {
    return(rep_like[[1]])
  }
  if (length(names) > 0L) {
    return(names[[1]])
  }
  if (!is.null(ctx) && is.list(ctx) && !is.null(ctx$doi) && nzchar(ctx$doi)) {
    return(study_folder_from_doi(normalize_doi(ctx$doi)))
  }
  "study"
}

#' Candidate paths for a replication data file
#'
#' Checks the study checkout, then \code{<root>/data/<study>/<file>}.
#'
#' @param rel_path Path relative to study root (e.g. \code{data/file.dta}).
#' @param study_root Normalized study repository root.
#' @param meta Parsed replication metadata.
#' @param ctx Optional paper context.
#' @return Character vector of paths checked.
#' @keywords internal
study_data_file_candidates <- function(rel_path, study_root, meta, ctx = NULL) {
  rel_path <- gsub("\\", "/", as.character(rel_path), fixed = TRUE)
  file_name <- basename(rel_path)
  study_name <- study_data_folder_name(meta, ctx)
  root <- study_data_root(ctx)
  candidates <- c(file.path(study_root, rel_path))
  sibling <- resolve_study_folder_path(meta, ctx)
  if (is.null(sibling) && !is.null(ctx) && !is.null(ctx$doi) && nzchar(ctx$doi)) {
    sibling <- resolve_local_study_folder(normalize_doi(as.character(ctx$doi)))
  }
  if (!is.null(sibling)) {
    sibling_path <- file.path(sibling, rel_path)
    study_norm <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
    sibling_norm <- normalizePath(sibling, winslash = "/", mustWork = FALSE)
    if (!identical(study_norm, sibling_norm)) {
      candidates <- c(candidates, sibling_path)
    }
  }
  candidates <- c(candidates, file.path(root, "data", study_name, file_name))
  unique(candidates)
}

#' Summarize a directory for error messages
#'
#' @param path Directory path.
#' @return Character scalar.
#' @keywords internal
describe_working_directory <- function(path = getwd()) {
  if (is.null(path) || !nzchar(path) || !dir.exists(path)) {
    return(paste0("Working directory missing: ", path))
  }
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  entries <- tryCatch(
    list.files(path, all.files = FALSE),
    error = function(e) character(0)
  )
  data_dir <- file.path(path, "data")
  data_entries <- if (dir.exists(data_dir)) {
    list.files(data_dir, all.files = FALSE)
  } else {
    "(no data/ folder)"
  }
  paste0(
    "Working directory: ", path, "\n",
    "Contents:\n  ", paste(if (length(entries)) entries else "(empty)", collapse = "\n  "),
    "\n",
    "data/:\n  ", paste(if (length(data_entries)) data_entries else "(empty)", collapse = "\n  ")
  )
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
  root <- study_data_root(ctx)
  study_name <- study_data_folder_name(meta, ctx)
  file_name <- basename(gsub("\\", "/", rel_path, fixed = TRUE))
  paste0(
    "Data file not found: ", rel_path, "\n",
    "Study folder (code): ", study_root, "\n",
    "Expected data path: ", file.path(root, "data", study_name, file_name), "\n",
    "Also checked:\n",
    paste0("  - ", checked, collapse = "\n"),
    "\n\n",
    describe_working_directory(root)
  )
}

#' Ensure replication data files exist under a study root
#'
#' Looks in the study checkout, then \code{data/<study>/<file>} under the
#' working directory. When found externally, links or copies into
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

#' Declared remote data entries from study metadata
#'
#' Reads \code{dataverse.files} (and optional top-level \code{data_files:}) from
#' study yaml. Each entry maps a local study-relative \code{path} to a remote
#' location via \code{url}, or Dataverse \code{id} / \code{file_id} (optional
#' \code{original: true} for native uploads behind \code{.tab} listings).
#'
#' This is **location wiring**, not a DAG step: raw inputs land under
#' \code{data/}; transform steps consume them after materialize.
#'
#' @param meta Parsed replication metadata (full study yaml).
#' @return List of named lists with at least \code{path}.
#' @keywords internal
declared_data_entries <- function(meta) {
  entries <- list()
  dv <- meta$dataverse %||% list()
  files <- dv$files %||% list()
  if (is.data.frame(files)) {
    files <- split(files, seq_len(nrow(files)))
  }
  if (length(files)) {
    entries <- c(entries, files)
  }
  top <- meta$data_files %||% list()
  if (is.data.frame(top)) {
    top <- split(top, seq_len(nrow(top)))
  }
  if (length(top)) {
    entries <- c(entries, top)
  }
  out <- list()
  for (entry in entries) {
    if (is.null(entry) || !is.list(entry)) {
      next
    }
    path <- as.character(entry$path %||% "")
    if (!nzchar(path)) {
      next
    }
    out[[length(out) + 1L]] <- entry
  }
  out
}

#' Resolve download URL for a declared data entry
#' @keywords internal
declared_data_entry_url <- function(entry, server = "dataverse.harvard.edu") {
  url <- as.character(entry$url %||% "")
  if (nzchar(url)) {
    return(url)
  }
  file_id <- as.character(entry$id %||% entry$file_id %||% "")
  if (!nzchar(file_id)) {
    return(NA_character_)
  }
  original <- isTRUE(entry$original) ||
    identical(tolower(as.character(entry$original %||% "")), "true")
  sprintf(
    "https://%s/api/access/datafile/%s%s",
    server,
    file_id,
    if (isTRUE(original)) "?format=original" else ""
  )
}

#' Download a URL to a local path (skip if present unless force)
#'
#' Thin httr wrapper used by declared-data materialize. Prefer this over
#' study-local download helpers.
#'
#' @param url Remote URL.
#' @param dest Destination path.
#' @param force Re-download even when \code{dest} exists and is non-empty.
#' @param timeout Seconds.
#' @return Invisibly, \code{dest}.
#' @keywords internal
download_url_to_path <- function(url, dest, force = FALSE, timeout = 600) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!isTRUE(force) && file.exists(dest) && isTRUE(file.info(dest)$size > 0)) {
    return(invisible(dest))
  }
  resp <- httr::GET(
    url,
    httr::write_disk(dest, overwrite = TRUE),
    httr::add_headers(`User-Agent` = "replicateEverything-declared-data/1.0"),
    httr::timeout(timeout)
  )
  if (httr::http_error(resp)) {
    unlink(dest)
    stop(
      "Download failed (HTTP ", httr::status_code(resp), "): ", url,
      call. = FALSE
    )
  }
  if (!file.exists(dest) || !isTRUE(file.info(dest)$size > 0)) {
    unlink(dest)
    stop("Downloaded empty file from ", url, call. = FALSE)
  }
  invisible(dest)
}

#' Materialize remotely declared study data into the study root
#'
#' Fetches files listed under \code{dataverse.files} / \code{data_files:} into
#' their declared local \code{path}s when missing. Not a pipeline step — call
#' automatically before runs, or explicitly for smoke checks.
#'
#' @param meta Parsed replication metadata, or a study root path / DOI that
#'   [get_replication_meta()] can resolve.
#' @param study_root Local study repository root. When \code{NULL}, uses
#'   \code{ctx$local_root} / [ensure_study_folder_local()].
#' @param ctx Optional paper context.
#' @param force Re-download existing files.
#' @param paths Optional character vector of relative paths to materialize;
#'   when set, only matching declared entries are fetched.
#' @return Invisibly, character vector of absolute paths written or already present.
#'
#' @examples
#' \dontrun{
#' # Blair et al. APSR: surgical Dataverse file wiring in replication.yml
#' materialize_declared_data("10.1017/S0003055422000284")
#' materialize_declared_data("10.1017/S0003055403000534")
#' }
#'
#' @export
materialize_declared_data <- function(
  meta,
  study_root = NULL,
  ctx = NULL,
  force = FALSE,
  paths = NULL
) {
  if (is.character(meta) && length(meta) == 1L) {
    meta <- get_replication_meta(meta)
  }
  if (is.null(study_root) || !nzchar(as.character(study_root[[1]] %||% ""))) {
    if (is.null(ctx)) {
      doi <- as.character(meta$paper$doi[[1]] %||% meta$paper$study_handle[[1]] %||% "")
      if (nzchar(doi)) {
        ctx <- tryCatch(paper_context(doi), error = function(e) NULL)
      }
    }
    study_root <- if (!is.null(ctx) && !is.null(ctx$local_root)) {
      ctx$local_root
    } else {
      ensure_study_folder_local(meta, ctx)
    }
  }
  if (is.null(study_root) || !dir.exists(study_root)) {
    stop(
      "materialize_declared_data() needs a local study root.",
      call. = FALSE
    )
  }
  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  meta <- complete_folder_study_meta(meta, study_root)

  entries <- declared_data_entries(meta)
  if (!length(entries)) {
    return(invisible(character(0)))
  }
  if (!is.null(paths)) {
    want <- unique(gsub("\\\\", "/", as.character(paths)))
    want <- want[nzchar(want)]
    entries <- Filter(
      function(e) gsub("\\\\", "/", as.character(e$path %||% "")) %in% want,
      entries
    )
  }
  if (!length(entries)) {
    return(invisible(character(0)))
  }

  dv <- meta$dataverse %||% list()
  server <- as.character(dv$server %||% "dataverse.harvard.edu")
  resolved <- character(0)
  for (entry in entries) {
    rel <- gsub("\\\\", "/", as.character(entry$path %||% ""))
    dest <- file.path(study_root, rel)
    url <- declared_data_entry_url(entry, server = server)
    if (!nzchar(url) || is.na(url)) {
      stop(
        "Declared data entry for '", rel, "' needs url: or id:/file_id:.",
        call. = FALSE
      )
    }
    if (!isTRUE(force) && file.exists(dest) && isTRUE(file.info(dest)$size > 0)) {
      resolved <- c(resolved, normalizePath(dest, winslash = "/", mustWork = FALSE))
      next
    }
    message("Fetching declared data: ", rel)
    download_url_to_path(url, dest, force = TRUE)
    resolved <- c(resolved, normalizePath(dest, winslash = "/", mustWork = FALSE))
  }
  invisible(resolved)
}

#' Materialize declared remote sources for missing study data paths
#' @keywords internal
materialize_declared_data_for_paths <- function(
  rel_paths,
  study_root,
  meta,
  ctx = NULL,
  force = FALSE
) {
  if (is.null(rel_paths) || !length(rel_paths)) {
    return(invisible(character(0)))
  }
  rel_paths <- unique(gsub("\\\\", "/", as.character(rel_paths)))
  rel_paths <- rel_paths[nzchar(rel_paths)]
  missing <- rel_paths[!file.exists(file.path(study_root, rel_paths)) |
    vapply(file.path(study_root, rel_paths), function(p) {
      !file.exists(p) || !isTRUE(file.info(p)$size > 0)
    }, logical(1))]
  if (!length(missing)) {
    return(invisible(character(0)))
  }
  declared <- declared_data_entries(meta)
  if (!length(declared)) {
    return(invisible(character(0)))
  }
  declared_paths <- vapply(
    declared,
    function(e) gsub("\\\\", "/", as.character(e$path %||% "")),
    character(1)
  )
  to_fetch <- intersect(missing, declared_paths)
  if (!length(to_fetch)) {
    return(invisible(character(0)))
  }
  materialize_declared_data(
    meta,
    study_root = study_root,
    ctx = ctx,
    force = force,
    paths = to_fetch
  )
}

#' Normalize a Dataverse dataset identifier for API URLs
#' @keywords internal
normalize_dataverse_persistent_id <- function(dataset) {
  dataset <- as.character(dataset[[1]] %||% dataset)
  dataset <- trimws(dataset)
  if (grepl("^doi:", dataset, ignore.case = TRUE)) {
    return(dataset)
  }
  if (grepl("^10\\.7910/DVN/", dataset)) {
    return(paste0("doi:", dataset))
  }
  if (grepl("^DVN/", dataset)) {
    return(paste0("doi:10.7910/", dataset))
  }
  dataset
}

#' URL for downloading a full dataset archive from Harvard Dataverse
#' @keywords internal
dataverse_dataset_archive_url <- function(
  dataset,
  server = "dataverse.harvard.edu",
  original = TRUE
) {
  pid <- normalize_dataverse_persistent_id(dataset)
  query <- list(persistentId = pid)
  if (isTRUE(original)) {
    query$format <- "original"
  }
  httr::modify_url(
    sprintf("https://%s/api/access/dataset/:persistentId/", server),
    query = query
  )
}

#' Download a full Dataverse dataset as a zip archive
#'
#' Use \code{format=original} so tabular uploads arrive as CSV/Stata/etc.,
#' not Dataverse \code{.tab} exports.
#'
#' @param dataset Dataverse dataset DOI or persistent id.
#' @param dest_zip Destination \code{.zip} path.
#' @param server Dataverse host.
#' @param original When \code{TRUE}, request native uploads (\code{format=original}).
#' @param timeout Seconds for the HTTP request.
#' @keywords internal
download_dataverse_dataset_archive <- function(
  dataset,
  dest_zip,
  server = "dataverse.harvard.edu",
  original = TRUE,
  timeout = 3600
) {
  dest_dir <- dirname(dest_zip)
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  url <- dataverse_dataset_archive_url(dataset, server = server, original = original)
  resp <- httr::GET(
    url,
    httr::write_disk(dest_zip, overwrite = TRUE),
    httr::add_headers(`User-Agent` = "replicateEverything-dataverse/1.0"),
    httr::timeout(timeout)
  )
  if (httr::http_error(resp)) {
    stop(
      "Dataverse dataset archive download failed: HTTP ",
      httr::status_code(resp),
      call. = FALSE
    )
  }
  invisible(dest_zip)
}

#' Extract a Dataverse dataset zip into a deposit directory
#'
#' Unzips in place. If the archive contains a single top-level directory that
#' holds \code{data/} or \code{scripts/}, that wrapper is hoisted away.
#'
#' @param zip_path Path to the downloaded archive.
#' @param deposit_root Target directory (e.g. \code{outputs/deposit}).
#' @param clean When \code{TRUE}, remove existing deposit contents except the zip.
#' @keywords internal
extract_dataverse_deposit_archive <- function(
  zip_path,
  deposit_root,
  clean = TRUE
) {
  if (!file.exists(zip_path)) {
    stop("Archive not found: ", zip_path, call. = FALSE)
  }
  dir.create(deposit_root, recursive = TRUE, showWarnings = FALSE)
  zip_abs <- normalizePath(zip_path, winslash = "/", mustWork = TRUE)
  if (isTRUE(clean)) {
    existing <- list.files(deposit_root, full.names = TRUE, all.files = TRUE, no.. = TRUE)
    existing <- existing[normalizePath(existing, winslash = "/", mustWork = FALSE) != zip_abs]
    if (length(existing)) {
      unlink(existing, recursive = TRUE, force = TRUE)
    }
  }
  staging <- file.path(deposit_root, ".archive_staging")
  unlink(staging, recursive = TRUE, force = TRUE)
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(zip_path, exdir = staging)
  src <- staging
  top <- list.files(staging, full.names = TRUE, recursive = FALSE, all.files = FALSE)
  if (length(top) == 1L && dir.exists(top[[1L]])) {
    inner <- top[[1L]]
    if (dir.exists(file.path(inner, "data")) || dir.exists(file.path(inner, "scripts"))) {
      src <- inner
    }
  }
  entries <- list.files(src, full.names = TRUE, recursive = FALSE, all.files = FALSE)
  for (entry in entries) {
    dest <- file.path(deposit_root, basename(entry))
    if (dir.exists(entry)) {
      if (dir.exists(dest)) {
        unlink(dest, recursive = TRUE, force = TRUE)
      }
      file.rename(entry, dest)
    } else {
      file.copy(entry, dest, overwrite = TRUE)
      unlink(entry)
    }
  }
  unlink(staging, recursive = TRUE, force = TRUE)
  invisible(deposit_root)
}

#' Download and extract a full Dataverse deposit in original format
#' @keywords internal
access_dataverse_deposit_archive <- function(
  dataset,
  deposit_root,
  server = "dataverse.harvard.edu",
  original = TRUE,
  timeout = 3600,
  clean = TRUE
) {
  zip_path <- file.path(deposit_root, ".dataset_original.zip")
  download_dataverse_dataset_archive(
    dataset,
    zip_path,
    server = server,
    original = original,
    timeout = timeout
  )
  extract_dataverse_deposit_archive(zip_path, deposit_root, clean = clean)
}

#' Verify expected paths exist under a deposit root
#' @keywords internal
verify_deposit_paths <- function(paths, deposit_root) {
  paths <- as.character(paths)
  paths <- paths[nzchar(paths)]
  missing <- paths[!file.exists(file.path(deposit_root, paths))]
  if (length(missing)) {
    stop(
      "Deposit missing expected files after archive extract:\n",
      paste0(" - ", missing, collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(paths)
}

#' Remove deposit files not listed in a manifest keep set
#'
#' After a full Dataverse archive extract, drops PDFs, HTML, extra scripts,
#' and other paths outside \code{keep_paths}. Preserves the cached archive zip
#' and other dotfiles named in \code{preserve}.
#'
#' @param keep_paths Character vector of relative paths to retain.
#' @param deposit_root Deposit directory (e.g. \code{outputs/deposit}).
#' @param preserve Basenames (or relative paths) always kept under \code{deposit_root}.
#' @keywords internal
prune_deposit_paths <- function(
  keep_paths,
  deposit_root,
  preserve = c(".dataset_original.zip", ".manifest_applied")
) {
  keep_paths <- as.character(keep_paths)
  keep_paths <- keep_paths[nzchar(keep_paths)]
  deposit_root <- normalizePath(deposit_root, winslash = "/", mustWork = FALSE)
  keep_abs <- normalizePath(
    file.path(deposit_root, keep_paths),
    winslash = "/",
    mustWork = FALSE
  )
  preserve_abs <- normalizePath(
    file.path(deposit_root, preserve),
    winslash = "/",
    mustWork = FALSE
  )
  keep_abs <- unique(c(keep_abs, preserve_abs))

  all_files <- list.files(
    deposit_root,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    no.. = TRUE
  )
  for (path in all_files) {
    path_abs <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (path_abs %in% keep_abs) {
      next
    }
    unlink(path, force = TRUE)
  }

  all_dirs <- list.dirs(deposit_root, recursive = TRUE, full.names = TRUE)
  all_dirs <- all_dirs[order(nchar(all_dirs), decreasing = TRUE)]
  for (dir_path in all_dirs) {
    if (identical(normalizePath(dir_path, winslash = "/"), deposit_root)) {
      next
    }
    entries <- list.files(dir_path, all.files = TRUE, no.. = TRUE)
    if (!length(entries)) {
      unlink(dir_path, recursive = TRUE, force = TRUE)
    }
  }

  invisible(keep_paths)
}

#' Download a single file listed in a Dataverse manifest row
#'
#' Manifest columns:
#' \describe{
#'   \item{id}{Dataverse file id}
#'   \item{path}{Local path under the deposit root (author-relative layout)}
#'   \item{original}{When \code{TRUE}, fetch native upload via \code{?format=original}
#'     (e.g. CSV behind a \code{.tab} name on Dataverse)}
#' }
#'
#' @param row One row from a manifest data frame.
#' @param deposit_root Directory to write into (e.g. \code{outputs/deposit}).
#' @param server Dataverse host.
#' @return Invisibly, the destination path.
#' @keywords internal
download_dataverse_manifest_file <- function(
  row,
  deposit_root,
  server = "dataverse.harvard.edu"
) {
  path <- as.character(row$path[[1]])
  file_id <- as.character(row$id[[1]])
  if (!nzchar(path) || !nzchar(file_id)) {
    stop("Manifest row requires id and path.", call. = FALSE)
  }
  dest <- file.path(deposit_root, path)
  original <- manifest_row_use_original(row)
  download_dataverse_file(file_id, dest, server = server, original = original)
}

#' Whether a manifest row should use Dataverse original-format download
#' @keywords internal
manifest_row_use_original <- function(row) {
  if (!"original" %in% names(row)) {
    return(FALSE)
  }
  val <- row$original[[1]]
  isTRUE(val) || identical(tolower(as.character(val)), "true")
}

#' Download a Harvard Dataverse file by id
#'
#' Prefers surgical file-level fetches (`api/access/datafile/<id>?format=original`)
#' over full dataset archives. Studies should call [fetch_dataverse_file()] rather
#' than inventing local `httr::GET` helpers.
#'
#' @param file_id Dataverse numeric file id.
#' @param dest Destination path.
#' @param server Dataverse host.
#' @param original When \code{TRUE}, append \code{?format=original} (native upload).
#' @param force Re-download even when \code{dest} exists and is non-empty.
#' @param timeout Seconds.
#' @return Invisibly, \code{dest}.
#' @keywords internal
download_dataverse_file <- function(
  file_id,
  dest,
  server = "dataverse.harvard.edu",
  original = FALSE,
  force = TRUE,
  timeout = 600
) {
  dest_dir <- dirname(dest)
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  if (!isTRUE(force) && file.exists(dest) && isTRUE(file.info(dest)$size > 0)) {
    return(invisible(dest))
  }
  url <- sprintf(
    "https://%s/api/access/datafile/%s%s",
    server,
    file_id,
    if (isTRUE(original)) "?format=original" else ""
  )
  download_url_to_path(url, dest, force = TRUE, timeout = timeout)
  invisible(dest)
}

#' Fetch a Dataverse file into a study-relative path (surgical pull)
#'
#' Downloads one file by Dataverse file id (or absolute URL) into the study
#' tree. Prefer this over full-dataset zip downloads and over study-local
#' download helpers. Typical Pattern B: write under \code{outputs/}.
#'
#' @param file_id Dataverse file id (ignored when \code{url} is set).
#' @param path Study-relative destination (e.g. \code{"outputs/data.dta"}).
#' @param url Optional direct URL (e.g. already including \code{?format=original}).
#' @param original When \code{TRUE} and using \code{file_id}, request native upload.
#' @param server Dataverse host.
#' @param study_root Local study root; defaults to \code{REPLICATE_STUDY_ROOT} or \code{"."}.
#' @param force Re-download existing files.
#' @return Invisibly, absolute destination path.
#'
#' @examples
#' \dontrun{
#' # Blair et al. APSR analysis .dta (Harvard Dataverse file id)
#' fetch_dataverse_file(
#'   file_id = "14058927",
#'   path = "outputs/analysis.dta",
#'   study_root = "../rep-10.1017-s0003055422000284"
#' )
#' }
#'
#' @export
fetch_dataverse_file <- function(
  file_id = NULL,
  path,
  url = NULL,
  original = TRUE,
  server = "dataverse.harvard.edu",
  study_root = NULL,
  force = TRUE
) {
  if (is.null(study_root) || !nzchar(as.character(study_root[[1]] %||% ""))) {
    study_root <- Sys.getenv("REPLICATE_STUDY_ROOT", unset = "")
    if (!nzchar(study_root)) {
      study_root <- "."
    }
  }
  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  rel <- gsub("\\\\", "/", as.character(path[[1]] %||% ""))
  if (!nzchar(rel)) {
    stop("fetch_dataverse_file() needs path =.", call. = FALSE)
  }
  dest <- file.path(study_root, rel)
  url <- as.character(url %||% "")
  if (!nzchar(url)) {
    fid <- as.character(file_id %||% "")
    if (!nzchar(fid)) {
      stop("fetch_dataverse_file() needs file_id = or url =.", call. = FALSE)
    }
    download_dataverse_file(
      fid,
      dest,
      server = server,
      original = isTRUE(original),
      force = force
    )
  } else {
    download_url_to_path(url, dest, force = force)
  }
  invisible(normalizePath(dest, winslash = "/", mustWork = FALSE))
}

#' Resolve surgical Dataverse file entries for an access step
#'
#' Reads step-level \code{files:} / \code{file_id} + \code{outputs:}, or falls
#' back to study \code{dataverse.file_id} mapped to the first output path.
#' @keywords internal
dataverse_access_step_entries <- function(rep, meta = NULL) {
  entries <- list()
  step_files <- rep$files %||% rep$dataverse$files %||% list()
  if (is.data.frame(step_files)) {
    step_files <- split(step_files, seq_len(nrow(step_files)))
  }
  for (entry in step_files) {
    if (is.null(entry) || !is.list(entry)) {
      next
    }
    path <- as.character(entry$path %||% "")
    if (!nzchar(path)) {
      next
    }
    entries[[length(entries) + 1L]] <- entry
  }
  if (length(entries)) {
    return(entries)
  }

  outs <- character(0)
  if (!is.null(rep$outputs) && length(rep$outputs)) {
    outs <- vapply(rep$outputs, function(x) as.character(x[[1]] %||% x), character(1))
    outs <- outs[nzchar(outs)]
  }
  fid <- as.character(
    rep$file_id %||%
      rep$dataverse$file_id %||% rep$dataverse$id %||%
      meta$dataverse$file_id %||% meta$dataverse$id %||% ""
  )
  if (nzchar(fid) && length(outs) >= 1L) {
    original <- rep$original %||% rep$dataverse$original %||%
      meta$dataverse$original %||% TRUE
    return(list(list(
      path = outs[[1]],
      id = fid,
      file_id = fid,
      original = original,
      url = as.character(rep$url %||% meta$dataverse$url %||% "")
    )))
  }
  list()
}

#' Run a Pattern B Dataverse access step (surgical file pulls → outputs/)
#' @keywords internal
run_dataverse_access_step <- function(
  rep,
  study_root,
  meta = NULL,
  force = TRUE
) {
  entries <- dataverse_access_step_entries(rep, meta = meta)
  if (!length(entries)) {
    stop(
      "engine: dataverse step '", rep$id %||% "?",
      "' needs files: (path + id/url) or file_id + outputs:.",
      call. = FALSE
    )
  }
  dv <- meta$dataverse %||% list()
  server <- as.character(
    rep$server %||% rep$dataverse$server %||% dv$server %||% "dataverse.harvard.edu"
  )
  written <- character(0)
  for (entry in entries) {
    rel <- gsub("\\\\", "/", as.character(entry$path %||% ""))
    fid <- as.character(entry$id %||% entry$file_id %||% "")
    url <- as.character(entry$url %||% "")
    original <- isTRUE(entry$original) ||
      identical(tolower(as.character(entry$original %||% "")), "true") ||
      (is.null(entry$original) && !nzchar(url))
    message("Fetching Dataverse file → ", rel)
    written <- c(
      written,
      fetch_dataverse_file(
        file_id = if (nzchar(fid)) fid else NULL,
        path = rel,
        url = if (nzchar(url)) url else NULL,
        original = original,
        server = server,
        study_root = study_root,
        force = force
      )
    )
  }
  invisible(written)
}

#' Download only manifest-listed Dataverse files (surgical Pattern C)
#'
#' When the manifest has an \code{id} column, fetches each file by id into the
#' deposit layout. Prefer this over [access_dataverse_deposit_archive()] unless
#' author scripts require a full deposit tree that cannot be reconstructed from
#' file ids.
#'
#' @param manifest_df Manifest data frame with \code{id} and \code{path}.
#' @param deposit_root Deposit directory.
#' @param server Dataverse host.
#' @param force Re-download existing files.
#' @return Invisibly, character vector of destination paths.
#' @keywords internal
access_dataverse_deposit_manifest_files <- function(
  manifest_df,
  deposit_root,
  server = "dataverse.harvard.edu",
  force = TRUE
) {
  if (is.null(manifest_df) || !nrow(manifest_df)) {
    stop("Manifest is empty.", call. = FALSE)
  }
  if (!"id" %in% names(manifest_df) || !"path" %in% names(manifest_df)) {
    stop(
      "Surgical deposit fetch needs manifest columns id and path. ",
      "Use fetch: archive_original only when file ids are unavailable.",
      call. = FALSE
    )
  }
  dir.create(deposit_root, recursive = TRUE, showWarnings = FALSE)
  written <- character(0)
  for (i in seq_len(nrow(manifest_df))) {
    row <- manifest_df[i, , drop = FALSE]
    fid <- as.character(row$id[[1]] %||% "")
    if (!nzchar(fid) || identical(fid, "NA")) {
      next
    }
    written <- c(
      written,
      download_dataverse_manifest_file(row, deposit_root, server = server)
    )
  }
  if (!length(written)) {
    stop(
      "No manifest rows with Dataverse file ids; cannot do a surgical deposit pull.",
      call. = FALSE
    )
  }
  invisible(written)
}

#' Build manifest rows from a Dataverse dataset inventory
#'
#' Tabular files map \code{path} to \code{originalFileName} when present
#' (author layout); otherwise to the listed filename.
#'
#' @param dataset Dataverse dataset DOI or persistent id.
#' @param server Dataverse host.
#' @param paths Optional character vector of Dataverse filenames to include.
#' @return Data frame with columns \code{id}, \code{path}, \code{dataverse_file},
#'   \code{original}.
#' @keywords internal
build_dataverse_manifest_from_dataset <- function(
  dataset,
  server = "dataverse.harvard.edu",
  paths = NULL
) {
  meta <- dataverse::get_dataset(dataset, server = server)
  files <- meta$files
  if (!is.null(paths) && length(paths)) {
    files <- files[files$filename %in% paths, , drop = FALSE]
  }
  if (!nrow(files)) {
    return(data.frame(
      id = character(0),
      path = character(0),
      dataverse_file = character(0),
      original = logical(0),
      stringsAsFactors = FALSE
    ))
  }
  orig <- as.character(files$originalFileName)
  orig[is.na(orig)] <- ""
  has_orig <- nzchar(orig)
  local_path <- files$filename
  local_path[has_orig] <- orig[has_orig]
  data.frame(
    id = as.character(files$id),
    path = gsub("\\\\", "/", local_path),
    dataverse_file = files$filename,
    original = has_orig,
    stringsAsFactors = FALSE
  )
}

#' Read Dataverse config from study metadata or local replication.yml
#' @keywords internal
study_dataverse_config <- function(meta, ctx) {
  dv <- meta$dataverse %||% list()
  if (length(dv)) {
    return(dv)
  }
  if (is.null(ctx$local_root)) {
    return(list())
  }
  local_yml <- file.path(ctx$local_root, "replication.yml")
  if (!file.exists(local_yml)) {
    return(list())
  }
  full <- tryCatch(yaml::read_yaml(local_yml), error = function(e) NULL)
  full$dataverse %||% list()
}

#' Summarize a Dataverse deposit for display-only prep steps
#'
#' Works from the study manifest and optional on-disk deposit marker even when
#' the full archive has not been downloaded in the current environment.
#' @keywords internal
summarize_dataverse_deposit <- function(meta, ctx, prep = NULL) {
  dv <- study_dataverse_config(meta, ctx)
  dataset <- as.character(dv$dataset %||% dv$doi %||% "")
  server <- as.character(dv$server %||% "dataverse.harvard.edu")
  deposit_rel <- as.character(dv$deposit_root %||% "outputs/deposit")
  if (!is.null(prep) && !is.null(prep$outputs) && length(prep$outputs)) {
    outs <- vapply(prep$outputs, function(x) as.character(x), character(1))
    deposit_rel <- dirname(outs[[1]])
  }
  deposit_root <- resolve_registry_file(deposit_rel, ctx, meta = meta, local_only = TRUE)
  if (is.null(deposit_root) || !nzchar(deposit_root)) {
    deposit_root <- if (!is.null(ctx$local_root)) {
      file.path(ctx$local_root, deposit_rel)
    } else {
      deposit_rel
    }
  }

  manifest_rel <- as.character(dv$manifest %||% "")
  manifest_paths <- character(0)
  if (nzchar(manifest_rel)) {
    manifest_file <- if (!is.null(ctx$local_root)) {
      local_manifest <- file.path(ctx$local_root, manifest_rel)
      if (file.exists(local_manifest)) local_manifest else NULL
    } else {
      NULL
    }
    if (is.null(manifest_file)) {
      manifest_file <- resolve_registry_file(manifest_rel, ctx, meta = meta, local_only = TRUE)
    }
    if (!is.null(manifest_file) && file.exists(manifest_file)) {
      manifest_df <- tryCatch(
        utils::read.csv(manifest_file, stringsAsFactors = FALSE),
        error = function(e) NULL
      )
      if (!is.null(manifest_df) && "path" %in% names(manifest_df)) {
        phase <- "mvp"
        if ("phase" %in% names(manifest_df)) {
          manifest_df <- manifest_df[
            is.na(manifest_df$phase) | manifest_df$phase == "" | manifest_df$phase == phase,
            ,
            drop = FALSE
          ]
        }
        manifest_paths <- as.character(manifest_df$path)
        manifest_paths <- manifest_paths[nzchar(manifest_paths)]
      }
    }
  }

  marker_path <- file.path(deposit_root, ".manifest_applied")
  marker_lines <- character(0)
  if (file.exists(marker_path)) {
    marker_lines <- readLines(marker_path, warn = FALSE, encoding = "UTF-8")
  }
  present <- if (length(manifest_paths)) {
    manifest_paths[file.exists(file.path(deposit_root, manifest_paths))]
  } else {
    character(0)
  }

  structure(
    list(
      step_type = "dataverse_access",
      dataset = dataset,
      server = server,
      deposit_root = normalize_path_slashes(deposit_root),
      deposit_rel = deposit_rel,
      fetch = as.character(dv$fetch %||% "archive_original"),
      n_expected = length(manifest_paths),
      n_present = length(present),
      expected_paths = manifest_paths,
      present_paths = present,
      marker_path = if (file.exists(marker_path)) normalize_path_slashes(marker_path) else NA_character_,
      marker_lines = marker_lines,
      ready = length(manifest_paths) > 0L && length(present) == length(manifest_paths)
    ),
    class = c("dataverse_deposit_summary", "prep_output_preview")
  )
}

#' @keywords internal
#' @exportS3Method format dataverse_deposit_summary
format.dataverse_deposit_summary <- function(x, ...) {
  lines <- c(
    "Dataverse deposit access",
    if (nzchar(x$dataset %||% "")) paste0("Dataset: ", x$dataset),
    if (nzchar(x$server %||% "")) paste0("Server: ", x$server),
    paste0("Deposit root: ", x$deposit_root),
    paste0("Fetch mode: ", x$fetch),
    paste0("Expected files: ", x$n_expected),
    paste0("Present on disk: ", x$n_present)
  )
  if (length(x$marker_lines)) {
    lines <- c(lines, "Marker:", paste0("  ", x$marker_lines))
  }
  if (length(x$expected_paths)) {
    preview_n <- min(8L, length(x$expected_paths))
    lines <- c(
      lines,
      "Manifest paths:",
      paste0("  ", head(x$expected_paths, preview_n))
    )
    if (length(x$expected_paths) > preview_n) {
      lines <- c(lines, paste0("  ... and ", length(x$expected_paths) - preview_n, " more"))
    }
  }
  paste(lines, collapse = "\n")
}

#' @keywords internal
#' @exportS3Method print dataverse_deposit_summary
print.dataverse_deposit_summary <- function(x, ...) {
  cat(format(x, ...), "\n")
  invisible(x)
}

#' Whether a prep step should use the Dataverse *full-deposit* summary display
#'
#' Pattern C only (manifest / deposit_root / access_deposit / archive fetch).
#' Pattern B surgical \code{access_data} → \code{outputs/*.dta} uses the normal
#' data-file preview — do **not** match bare \code{"access"} in the step id.
#' @keywords internal
is_dataverse_access_prep_step <- function(prep, meta, ctx = NULL) {
  if (is.null(prep) || !is.list(prep)) {
    return(FALSE)
  }
  id <- tolower(as.character(prep$id %||% ""))
  code <- tolower(as.character(prep$code %||% ""))
  if (grepl("access_deposit|deposit", id) ||
      grepl("access_deposit|deposit", code)) {
    return(TRUE)
  }
  outs <- tolower(paste(unlist(prep$outputs %||% list()), collapse = " "))
  if (grepl("deposit", outs)) {
    return(TRUE)
  }
  if (!is.null(ctx)) {
    dv <- study_dataverse_config(meta, ctx)
    fetch <- tolower(as.character(dv$fetch %||% ""))
    if (nzchar(as.character(dv$manifest %||% "")) &&
        grepl("archive|deposit", fetch)) {
      if (grepl("access|deposit|dataverse", id) || grepl("deposit", outs)) {
        return(TRUE)
      }
    }
  }
  FALSE
}

#' Summarize a Pattern B surgical Dataverse file access for Display
#'
#' Always available from yaml (file id + destination path) even when the
#' fetched binary is gitignored and not on disk in this session.
#' @keywords internal
summarize_dataverse_file_access <- function(meta, ctx, prep = NULL) {
  entries <- dataverse_access_step_entries(prep %||% list(), meta = meta)
  dv <- meta$dataverse %||% list()
  server <- as.character(
    prep$server %||% prep$dataverse$server %||% dv$server %||% "dataverse.harvard.edu"
  )
  dataset <- as.character(dv$dataset %||% dv$doi %||% "")
  rows <- lapply(entries, function(entry) {
    fid <- as.character(entry$id %||% entry$file_id %||% "")
    path <- as.character(entry$path %||% "")
    original <- isTRUE(entry$original) ||
      identical(tolower(as.character(entry$original %||% "")), "true") ||
      (is.null(entry$original) && !nzchar(as.character(entry$url %||% "")))
    url <- as.character(entry$url %||% "")
    if (!nzchar(url) && nzchar(fid)) {
      url <- paste0(
        "https://", server, "/api/access/datafile/", fid,
        if (isTRUE(original)) "?format=original" else ""
      )
    }
    local_path <- if (!is.null(ctx$local_root) && nzchar(path)) {
      file.path(ctx$local_root, path)
    } else {
      path
    }
    list(
      file_id = fid,
      path = path,
      url = url,
      original = isTRUE(original),
      present = nzchar(as.character(local_path %||% "")) &&
        file.exists(as.character(local_path))
    )
  })
  structure(
    list(
      step_type = "dataverse_file_access",
      dataset = dataset,
      server = server,
      files = rows,
      n_expected = length(rows),
      n_present = sum(vapply(rows, function(r) isTRUE(r$present), logical(1))),
      ready = length(rows) > 0L &&
        all(vapply(rows, function(r) isTRUE(r$present), logical(1)))
    ),
    class = c("dataverse_file_access_summary", "prep_output_preview")
  )
}

#' @keywords internal
#' @exportS3Method format dataverse_file_access_summary
format.dataverse_file_access_summary <- function(x, ...) {
  lines <- c(
    "Dataverse surgical file access",
    if (nzchar(x$dataset %||% "")) paste0("Dataset: ", x$dataset),
    if (nzchar(x$server %||% "")) paste0("Server: ", x$server),
    paste0(
      "Files: ", x$n_present, " of ", x$n_expected,
      " present on disk in this session"
    )
  )
  for (f in x$files %||% list()) {
    lines <- c(
      lines,
      paste0(
        "  - ", f$path %||% "?",
        if (nzchar(f$file_id %||% "")) paste0(" (file id ", f$file_id, ")") else "",
        if (isTRUE(f$present)) " [present]" else " [fetch on Run]"
      )
    )
    if (nzchar(f$url %||% "")) {
      lines <- c(lines, paste0("    ", f$url))
    }
  }
  paste(lines, collapse = "\n")
}

#' @keywords internal
#' @exportS3Method print dataverse_file_access_summary
print.dataverse_file_access_summary <- function(x, ...) {
  cat(format(x, ...), "\n")
  invisible(x)
}

#' Whether a prep step is a Pattern B surgical Dataverse file access
#' @keywords internal
is_dataverse_file_access_prep_step <- function(prep, meta = NULL) {
  if (is.null(prep) || !is.list(prep)) {
    return(FALSE)
  }
  if (is_dataverse_replication(prep, meta$paper %||% NULL)) {
    return(TRUE)
  }
  fid <- as.character(
    prep$file_id %||% prep$dataverse$file_id %||%
      meta$dataverse$file_id %||% ""
  )
  outs <- tolower(paste(unlist(prep$outputs %||% list()), collapse = " "))
  nzchar(fid) && grepl("\\.(dta|csv|rds|tab)$", outs)
}

#' Build a display object for a prep step when no HTML artifact exists
#' @keywords internal
load_prep_step_display <- function(meta, ctx, prep) {
  if (is_dataverse_access_prep_step(prep, meta, ctx = ctx)) {
    return(summarize_dataverse_deposit(meta, ctx, prep = prep))
  }
  path <- prep_output_path(prep, ctx, meta = meta)
  if (!is.null(path) && file.exists(path)) {
    ext <- tolower(tools::file_ext(path))
    if (ext %in% c("html", "png", "svg")) {
      return(load_artifact_file_path(path))
    }
    if (ext %in% c("rds", "csv", "dta")) {
      return(preview_data_file(path))
    }
    return(structure(
      list(
        path = path,
        note = paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      ),
      class = "prep_output_preview"
    ))
  }
  # Pattern B: yaml always supports a Display summary (never "not on disk" error).
  if (is_dataverse_file_access_prep_step(prep, meta = meta)) {
    return(summarize_dataverse_file_access(meta, ctx, prep = prep))
  }
  rel <- if (!is.null(prep$outputs) && length(prep$outputs)) {
    as.character(prep$outputs[[1]][[1]] %||% prep$outputs[[1]])
  } else {
    NA_character_
  }
  structure(
    list(
      path = path %||% NA_character_,
      note = paste0(
        "Output not prepared for display yet",
        if (isTRUE(nzchar(rel))) paste0(": ", rel) else "",
        ". This step is registered; rebuild study outputs or mark it incomplete."
      )
    ),
    class = "prep_output_preview"
  )
}

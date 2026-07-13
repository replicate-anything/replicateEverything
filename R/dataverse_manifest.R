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
#' @param file_id Dataverse numeric file id.
#' @param dest Destination path.
#' @param server Dataverse host.
#' @param original When \code{TRUE}, append \code{?format=original} (native upload).
#' @keywords internal
download_dataverse_file <- function(
  file_id,
  dest,
  server = "dataverse.harvard.edu",
  original = FALSE
) {
  dest_dir <- dirname(dest)
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  url <- sprintf(
    "https://%s/api/access/datafile/%s%s",
    server,
    file_id,
    if (isTRUE(original)) "?format=original" else ""
  )
  resp <- httr::GET(
    url,
    httr::write_disk(dest, overwrite = TRUE),
    httr::add_headers(`User-Agent` = "replicateEverything-dataverse/1.0"),
    httr::timeout(600)
  )
  if (httr::http_error(resp)) {
    stop(
      "Dataverse download failed for file id ", file_id, ": HTTP ",
      httr::status_code(resp), call. = FALSE
    )
  }
  invisible(dest)
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

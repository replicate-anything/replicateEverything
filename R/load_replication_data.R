#' Load replication data files
#'
#' Supports CSV, RDS, and Stata DTA files from a local registry checkout or
#' remote raw GitHub URLs.
#'
#' @param data_files Character vector of paths relative to the paper folder.
#' @param ctx Paper context from \code{paper_context()}.
#'
#' @return A data frame, a named list of objects, or \code{NULL}.
#' @param meta Optional parsed replication metadata for external data lookup.
#' @keywords internal
load_replication_data <- function(data_files, ctx, meta = NULL) {
  if (is.null(data_files)) {
    return(NULL)
  }

  if (is.list(data_files)) {
    data_files <- unlist(data_files, use.names = FALSE)
  }

  data_files <- as.character(data_files)
  data_files <- data_files[nzchar(data_files)]

  if (length(data_files) == 0) {
    return(NULL)
  }

  loaded <- lapply(data_files, function(path) {
    read_data_file(path, ctx, meta = meta)
  })

  if (length(loaded) == 1) {
    return(loaded[[1]])
  }

  stats::setNames(loaded, tools::file_path_sans_ext(basename(data_files)))
}

#' @keywords internal
read_data_file <- function(path, ctx, meta = NULL) {
  ext <- tolower(tools::file_ext(path))

  if (!is.null(meta)) {
    base_root <- extended_study_base_root(meta)
    if (!is.null(base_root)) {
      base_path <- file.path(base_root, path)
      if (file.exists(base_path)) {
        return(read_data_path(base_path, ext))
      }
    }
  }

  if (!is.null(ctx$local_root) && dir.exists(ctx$local_root) && !is.null(meta)) {
    ensure_study_data_files(path, ctx$local_root, meta, ctx)
  }

  local_path <- if (!is.null(ctx$local_root)) {
    file.path(ctx$local_root, path)
  } else {
    NA_character_
  }

  if (!is.na(local_path) && file.exists(local_path)) {
    return(read_data_path(local_path, ext))
  }

  if (!is.null(meta)) {
    base_root <- extended_study_base_root(meta)
    if (!is.null(base_root) && !identical(base_root, ctx$local_root)) {
      base_path <- file.path(base_root, path)
      if (file.exists(base_path)) {
        return(read_data_path(base_path, ext))
      }
    }
  }

  if (!is.null(ctx$local_root) && !is.null(meta)) {
    hit <- resolve_study_data_file(path, ctx$local_root, meta, ctx)
    if (isTRUE(hit$found)) {
      return(read_data_path(hit$path, ext))
    }
  }

  url <- paste0(ctx$base_url, "/", path)
  tmp <- tempfile(fileext = paste0(".", ext))
  mode <- if (ext %in% c("rds", "dta")) "wb" else "wt"
  utils::download.file(url, tmp, quiet = TRUE, mode = mode)
  on.exit(unlink(tmp), add = TRUE)
  read_data_path(tmp, ext)
}

#' @keywords internal
read_data_path <- function(path, ext = tolower(tools::file_ext(path))) {
  switch(
    ext,
    csv = utils::read.csv(path, stringsAsFactors = FALSE),
    rds = readRDS(path),
    dta = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Reading .dta files requires the 'haven' package.")
      }
      haven::read_dta(path)
    },
    stop("Unsupported data file format: .", ext)
  )
}

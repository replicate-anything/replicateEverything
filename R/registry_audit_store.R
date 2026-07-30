#' Incremental registry audit job store (`audit_jobs.csv`)
#'
#' Flat CSV of per-job audit rows. [write_registry_audit_record()] upserts
#' audited jobs and rebuilds derived \code{audit_summary.json} from the
#' **full** CSV so a one-DOI audit never wipes the portfolio health bar.
#'
#' @name registry_audit_store
#' @keywords internal
NULL

#' Canonical column order for \code{audit_jobs.csv}
#' @keywords internal
AUDIT_JOBS_COLUMNS <- c(
  "doi",
  "folder",
  "title",
  "object",
  "object_label",
  "type",
  "engine",
  "success",
  "run_ok",
  "substantive_ok",
  "seconds",
  "runtime_category",
  "timed_out",
  "skipped",
  "timeout_seconds",
  "error_snippet",
  "progress_category",
  "last_checked_at",
  "last_success_at",
  "source"
)

#' Path to the registry audit jobs CSV
#'
#' @param registry_root Optional registry repository root.
#' @return Character path, or \code{""} if the registry root is unknown.
#' @keywords internal
registry_audit_jobs_path <- function(registry_root = NULL) {
  root <- registry_root %||% getOption("replicateEverything.registry_root", NULL)
  if (is.null(root) || !nzchar(root)) {
    root <- auto_detect_registry_root()
  }
  if (is.null(root) || !nzchar(root)) {
    return("")
  }
  file.path(root, "audit_jobs.csv")
}

#' Empty audit-jobs data frame with the canonical schema
#' @keywords internal
empty_audit_jobs_df <- function() {
  data.frame(
    doi = character(0),
    folder = character(0),
    title = character(0),
    object = character(0),
    object_label = character(0),
    type = character(0),
    engine = character(0),
    success = logical(0),
    run_ok = logical(0),
    substantive_ok = logical(0),
    seconds = numeric(0),
    runtime_category = character(0),
    timed_out = logical(0),
    skipped = logical(0),
    timeout_seconds = numeric(0),
    error_snippet = character(0),
    progress_category = character(0),
    last_checked_at = character(0),
    last_success_at = character(0),
    source = character(0),
    stringsAsFactors = FALSE
  )
}

#' Normalize a UTC timestamp string for CSV storage
#' @keywords internal
audit_jobs_format_time <- function(x) {
  if (inherits(x, "POSIXt")) {
    return(format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  x <- trimws(as.character(x[[1]] %||% x %||% ""))
  if (!nzchar(x) || identical(x, "NA")) {
    return(NA_character_)
  }
  x
}

#' Stable upsert key for a job row (doi × object × engine)
#' @keywords internal
audit_jobs_row_key <- function(doi, object, engine) {
  doi_n <- vapply(
    as.character(doi %||% ""),
    function(d) {
      d <- trimws(d)
      if (!nzchar(d)) {
        return("")
      }
      tryCatch(normalize_doi(d), error = function(e) d)
    },
    character(1)
  )
  obj <- trimws(as.character(object %||% ""))
  obj[is.na(obj)] <- ""
  eng <- tolower(trimws(as.character(engine %||% "")))
  eng[is.na(eng)] <- ""
  paste(doi_n, obj, eng, sep = "\t")
}

#' Coerce CSV / R logical-ish values to logical (preserving NA)
#' @keywords internal
audit_jobs_as_logical <- function(x) {
  if (is.logical(x)) {
    return(x)
  }
  x_chr <- trimws(tolower(as.character(x)))
  out <- rep(NA, length(x_chr))
  out[x_chr %in% c("true", "t", "1", "yes")] <- TRUE
  out[x_chr %in% c("false", "f", "0", "no")] <- FALSE
  out
}

#' Ensure a data frame has the audit-jobs schema (fill missing cols)
#' @keywords internal
normalize_audit_jobs_df <- function(df) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
    return(empty_audit_jobs_df())
  }
  n <- nrow(df)
  defaults <- list(
    doi = "",
    folder = "",
    title = "",
    object = "",
    object_label = "",
    type = "",
    engine = "",
    success = NA,
    run_ok = NA,
    substantive_ok = NA,
    seconds = NA_real_,
    runtime_category = "",
    timed_out = FALSE,
    skipped = FALSE,
    timeout_seconds = NA_real_,
    error_snippet = "",
    progress_category = "",
    last_checked_at = NA_character_,
    last_success_at = NA_character_,
    source = ""
  )
  for (nm in names(defaults)) {
    if (!nm %in% names(df)) {
      df[[nm]] <- rep(defaults[[nm]], n)
    }
  }
  df$doi <- as.character(df$doi %||% "")
  df$folder <- as.character(df$folder %||% "")
  df$title <- as.character(df$title %||% "")
  df$object <- as.character(df$object %||% "")
  df$object_label <- as.character(df$object_label %||% "")
  df$type <- as.character(df$type %||% "")
  df$engine <- as.character(df$engine %||% "")
  df$success <- audit_jobs_as_logical(df$success)
  df$run_ok <- audit_jobs_as_logical(df$run_ok)
  df$substantive_ok <- audit_jobs_as_logical(df$substantive_ok)
  df$seconds <- as.numeric(df$seconds)
  df$runtime_category <- as.character(df$runtime_category %||% "")
  df$timed_out <- audit_jobs_as_logical(df$timed_out)
  df$timed_out[is.na(df$timed_out)] <- FALSE
  df$skipped <- audit_jobs_as_logical(df$skipped)
  df$skipped[is.na(df$skipped)] <- FALSE
  df$timeout_seconds <- as.numeric(df$timeout_seconds)
  df$error_snippet <- as.character(df$error_snippet %||% "")
  df$error_snippet[is.na(df$error_snippet)] <- ""
  df$progress_category <- as.character(df$progress_category %||% "")
  df$last_checked_at <- as.character(df$last_checked_at %||% "")
  df$last_success_at <- as.character(df$last_success_at %||% "")
  df$source <- as.character(df$source %||% "")

  # Recompute progress_category when blank.
  blank_cat <- !nzchar(trimws(df$progress_category)) |
    is.na(df$progress_category)
  if (any(blank_cat)) {
    df$progress_category[blank_cat] <- vapply(
      which(blank_cat),
      function(i) {
        audit_progress_category(
          success = df$success[[i]],
          timed_out = df$timed_out[[i]],
          skipped = df$skipped[[i]],
          substantive_ok = df$substantive_ok[[i]],
          error_snippet = df$error_snippet[[i]]
        )
      },
      character(1)
    )
  }

  df[, AUDIT_JOBS_COLUMNS, drop = FALSE]
}

#' Read \code{audit_jobs.csv} from the registry
#'
#' @param registry_root Optional registry root.
#' @return Data frame (possibly empty) with canonical columns.
#' @keywords internal
read_registry_audit_jobs <- function(registry_root = NULL) {
  path <- registry_audit_jobs_path(registry_root)
  if (!nzchar(path) || !file.exists(path)) {
    return(empty_audit_jobs_df())
  }
  raw <- tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("NA", "")),
    error = function(e) NULL
  )
  if (is.null(raw)) {
    return(empty_audit_jobs_df())
  }
  normalize_audit_jobs_df(raw)
}

#' Write audit jobs CSV atomically
#' @keywords internal
write_registry_audit_jobs <- function(jobs, registry_root = NULL) {
  path <- registry_audit_jobs_path(registry_root)
  if (!nzchar(path)) {
    stop("Could not resolve registry root for audit jobs CSV.", call. = FALSE)
  }
  jobs <- normalize_audit_jobs_df(jobs)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".tmp")
  utils::write.csv(jobs, tmp, row.names = FALSE, na = "")
  if (file.exists(path)) {
    unlink(path)
  }
  ok <- file.rename(tmp, path)
  if (!isTRUE(ok)) {
    file.copy(tmp, path, overwrite = TRUE)
    unlink(tmp)
  }
  invisible(path)
}

#' Look up bake / artifact fallback for last_success_at
#'
#' Prefers \code{recorded_at} from study bake timings; else artifact mtime.
#'
#' @keywords internal
audit_job_bake_success_at <- function(
  doi,
  object,
  engine = NULL,
  repo = NULL,
  folder = NULL,
  study_root = NULL
) {
  object <- as.character(object[[1]] %||% "")
  if (!nzchar(object)) {
    return(NA_character_)
  }

  root <- study_root
  if (is.null(root) || !nzchar(as.character(root[[1]] %||% ""))) {
    root <- tryCatch(
      resolve_local_study_folder(doi),
      error = function(e) NULL
    )
  }
  if (is.null(root) && !is.null(folder) && nzchar(as.character(folder[[1]] %||% ""))) {
    folders_root <- getOption("replicateEverything.study_folders_root", NULL)
    if (!is.null(folders_root) && nzchar(folders_root)) {
      cand <- file.path(folders_root, as.character(folder[[1]]))
      if (dir.exists(cand)) {
        root <- cand
      }
    }
  }

  if (!is.null(root) && nzchar(as.character(root[[1]] %||% ""))) {
    timings <- tryCatch(
      read_study_replication_timings(root),
      error = function(e) list(steps = list())
    )
    rec <- timings$steps[[object]]
    if (is.list(rec)) {
      at <- audit_jobs_format_time(rec$recorded_at %||% "")
      if (!is.na(at) && nzchar(at)) {
        return(at)
      }
    }
  }

  art <- tryCatch(
    local_artifact_path(
      doi,
      object,
      repo = repo,
      folder = folder,
      language = engine
    ),
    error = function(e) NULL
  )
  if (!is.null(art) && nzchar(art) && file.exists(art)) {
    info <- file.info(art)
    mtime <- info$mtime[[1]]
    if (inherits(mtime, "POSIXt") && !is.na(mtime)) {
      return(audit_jobs_format_time(mtime))
    }
  }
  NA_character_
}

#' Convert audit results data frame rows into CSV job rows
#'
#' @param results Audit results data frame.
#' @param checked_at POSIXct or character UTC timestamp for this write.
#' @param source Provenance label (\code{"audit"}, \code{"bake"}, \ldots).
#' @param prior_jobs Optional existing jobs (to preserve \code{last_success_at}).
#' @return Normalized jobs data frame.
#' @keywords internal
audit_results_to_jobs_rows <- function(
  results,
  checked_at,
  source = "audit",
  prior_jobs = NULL
) {
  if (is.null(results) || !is.data.frame(results) || nrow(results) == 0L) {
    return(empty_audit_jobs_df())
  }
  checked <- audit_jobs_format_time(checked_at)
  prior <- normalize_audit_jobs_df(prior_jobs)
  prior_keys <- if (nrow(prior)) {
    audit_jobs_row_key(prior$doi, prior$object, prior$engine)
  } else {
    character(0)
  }

  n <- nrow(results)
  folder <- if ("folder" %in% names(results)) {
    as.character(results$folder)
  } else {
    rep("", n)
  }
  success <- audit_jobs_as_logical(results$success)
  timed_out <- audit_jobs_as_logical(results$timed_out)
  timed_out[is.na(timed_out)] <- FALSE
  skipped <- if ("skipped" %in% names(results)) {
    audit_jobs_as_logical(results$skipped)
  } else {
    rep(FALSE, n)
  }
  skipped[is.na(skipped)] <- FALSE
  substantive_ok <- if ("substantive_ok" %in% names(results)) {
    audit_jobs_as_logical(results$substantive_ok)
  } else {
    rep(NA, n)
  }
  run_ok <- if ("run_ok" %in% names(results)) {
    audit_jobs_as_logical(results$run_ok)
  } else {
    success
  }
  err <- if ("error_snippet" %in% names(results)) {
    as.character(results$error_snippet)
  } else {
    rep("", n)
  }
  err[is.na(err)] <- ""

  progress <- vapply(
    seq_len(n),
    function(i) {
      audit_progress_category(
        success = success[[i]],
        timed_out = timed_out[[i]],
        skipped = skipped[[i]],
        substantive_ok = substantive_ok[[i]],
        error_snippet = err[[i]]
      )
    },
    character(1)
  )

  keys <- audit_jobs_row_key(results$doi, results$object, results$engine)
  last_success <- rep(NA_character_, n)
  for (i in seq_len(n)) {
    if (isTRUE(success[[i]])) {
      last_success[[i]] <- checked
      next
    }
    # Preserve prior successful audit time when this pass failed/timed out.
    hit <- match(keys[[i]], prior_keys)
    if (!is.na(hit)) {
      prev <- audit_jobs_format_time(prior$last_success_at[[hit]])
      if (!is.na(prev) && nzchar(prev)) {
        last_success[[i]] <- prev
        next
      }
    }
    # Bake / artifact mtime fallback.
    last_success[[i]] <- audit_job_bake_success_at(
      results$doi[[i]],
      results$object[[i]],
      engine = results$engine[[i]],
      folder = folder[[i]]
    )
  }

  out <- data.frame(
    doi = as.character(results$doi),
    folder = folder,
    title = as.character(results$title %||% ""),
    object = as.character(results$object %||% ""),
    object_label = as.character(results$object_label %||% ""),
    type = as.character(results$type %||% ""),
    engine = as.character(results$engine %||% ""),
    success = success,
    run_ok = run_ok,
    substantive_ok = substantive_ok,
    seconds = as.numeric(results$seconds),
    runtime_category = as.character(results$runtime_category %||% ""),
    timed_out = timed_out,
    skipped = skipped,
    timeout_seconds = as.numeric(results$timeout_seconds %||% NA_real_),
    error_snippet = err,
    progress_category = progress,
    last_checked_at = rep(checked, n),
    last_success_at = last_success,
    source = rep(as.character(source[[1]] %||% "audit"), n),
    stringsAsFactors = FALSE
  )
  normalize_audit_jobs_df(out)
}

#' Upsert job rows into the registry CSV (by doi × object × engine)
#'
#' @param new_rows Jobs data frame to merge in.
#' @param registry_root Registry root.
#' @return Invisibly, the merged jobs data frame.
#' @keywords internal
upsert_registry_audit_jobs <- function(new_rows, registry_root = NULL) {
  existing <- read_registry_audit_jobs(registry_root)
  incoming <- normalize_audit_jobs_df(new_rows)
  if (nrow(incoming) == 0L) {
    return(invisible(existing))
  }

  # Preserve prior last_success_at when this pass is not a success.
  if (nrow(existing) > 0L) {
    exist_keys <- audit_jobs_row_key(existing$doi, existing$object, existing$engine)
    new_keys <- audit_jobs_row_key(incoming$doi, incoming$object, incoming$engine)
    for (i in seq_len(nrow(incoming))) {
      if (isTRUE(incoming$success[[i]])) {
        next
      }
      cur <- audit_jobs_format_time(incoming$last_success_at[[i]])
      if (!is.na(cur) && nzchar(cur)) {
        next
      }
      hit <- match(new_keys[[i]], exist_keys)
      if (!is.na(hit)) {
        prev <- audit_jobs_format_time(existing$last_success_at[[hit]])
        if (!is.na(prev) && nzchar(prev)) {
          incoming$last_success_at[[i]] <- prev
        }
      }
    }
  }

  if (nrow(existing) == 0L) {
    write_registry_audit_jobs(incoming, registry_root)
    return(invisible(incoming))
  }

  exist_keys <- audit_jobs_row_key(existing$doi, existing$object, existing$engine)
  new_keys <- audit_jobs_row_key(incoming$doi, incoming$object, incoming$engine)
  keep <- existing[!exist_keys %in% new_keys, , drop = FALSE]
  merged <- rbind(keep, incoming)
  rownames(merged) <- NULL
  ord <- order(
    as.character(merged$doi),
    as.character(merged$object),
    as.character(merged$engine)
  )
  merged <- merged[ord, , drop = FALSE]
  write_registry_audit_jobs(merged, registry_root)
  invisible(merged)
}

#' Convert jobs CSV rows back to an audit results-like data frame
#' @keywords internal
audit_jobs_to_results <- function(jobs) {
  jobs <- normalize_audit_jobs_df(jobs)
  if (nrow(jobs) == 0L) {
    return(data.frame(
      doi = character(0),
      title = character(0),
      object = character(0),
      object_label = character(0),
      type = character(0),
      engine = character(0),
      success = logical(0),
      run_ok = logical(0),
      substantive_ok = logical(0),
      seconds = numeric(0),
      runtime_category = character(0),
      timed_out = logical(0),
      skipped = logical(0),
      timeout_seconds = numeric(0),
      error_snippet = character(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    doi = jobs$doi,
    title = jobs$title,
    object = jobs$object,
    object_label = jobs$object_label,
    type = jobs$type,
    engine = jobs$engine,
    success = jobs$success,
    run_ok = jobs$run_ok,
    substantive_ok = jobs$substantive_ok,
    seconds = jobs$seconds,
    runtime_category = jobs$runtime_category,
    timed_out = jobs$timed_out,
    skipped = jobs$skipped,
    timeout_seconds = jobs$timeout_seconds,
    error_snippet = jobs$error_snippet,
    stringsAsFactors = FALSE
  )
}

#' Build summary list + progress counts from full jobs CSV
#' @keywords internal
summary_from_audit_jobs <- function(jobs, meta = list()) {
  jobs <- normalize_audit_jobs_df(jobs)
  results <- audit_jobs_to_results(jobs)
  progress <- audit_progress_counts(results = results)

  n_ok <- sum(jobs$success %in% TRUE, na.rm = TRUE)
  n_skip <- sum(jobs$skipped %in% TRUE, na.rm = TRUE)
  n_fail <- sum(jobs$success %in% FALSE, na.rm = TRUE)
  n_timeout <- sum(jobs$timed_out %in% TRUE, na.rm = TRUE)
  n_substantive_fail <- sum(
    !is.na(jobs$substantive_ok) & !jobs$substantive_ok,
    na.rm = TRUE
  )
  n_studies <- length(unique(jobs$doi[nzchar(trimws(jobs$doi))]))

  list(
    studies = as.integer(meta$studies %||% n_studies),
    runs = nrow(jobs),
    success = n_ok,
    failed = n_fail,
    timed_out = n_timeout,
    skipped = n_skip,
    substantive_failed = n_substantive_fail,
    missing_engine = as.integer(progress[["missing_engine"]] %||% 0L),
    progress = as.list(progress),
    missing_source_repository = meta$missing_source_repository %||% list()
  )
}

#' Write derived \code{audit_summary.json} (+ RDS) from jobs CSV / audit meta
#'
#' @param jobs Full jobs data frame.
#' @param audit Optional latest \code{audit_everything} object (for patience /
#'   timestamps / missing_source on this write).
#' @param registry_root Registry root.
#' @return Invisibly, list of paths.
#' @keywords internal
write_derived_registry_audit_summary <- function(
  jobs,
  audit = NULL,
  registry_root = NULL
) {
  summary_path <- registry_audit_summary_path(registry_root)
  rds_path <- registry_audit_rds_path(registry_root)
  if (!nzchar(summary_path)) {
    stop("Could not resolve registry root for audit summary.", call. = FALSE)
  }

  meta <- list()
  if (!is.null(audit) && is.list(audit$summary)) {
    meta$missing_source_repository <- as.list(
      audit$summary$missing_source_repository %||% character(0)
    )
    # Prefer portfolio study count from index when present on this audit.
    if (!is.null(audit$summary$studies)) {
      # studies on a filtered audit is only the audited subset — use CSV unique.
      meta$studies <- NULL
    }
  }
  sm <- summary_from_audit_jobs(jobs, meta = meta)

  finished_at <- if (!is.null(audit$finished_at)) {
    audit$finished_at
  } else {
    Sys.time()
  }
  started_at <- if (!is.null(audit$started_at)) {
    audit$started_at
  } else {
    finished_at
  }
  patience <- if (!is.null(audit$patience)) {
    audit$patience
  } else {
    NA_real_
  }

  payload <- list(
    patience = patience,
    started_at = audit_jobs_format_time(started_at),
    finished_at = audit_jobs_format_time(finished_at),
    studies = sm$studies,
    runs = sm$runs,
    success = sm$success,
    failed = sm$failed,
    timed_out = sm$timed_out,
    skipped = sm$skipped %||% 0L,
    substantive_failed = sm$substantive_failed %||% 0L,
    missing_engine = sm$missing_engine %||% 0L,
    progress = sm$progress,
    missing_source_repository = sm$missing_source_repository %||% list()
  )
  jsonlite::write_json(
    payload,
    summary_path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )

  # Rebuild RDS snapshot from full CSV so lookups see the portfolio.
  results <- audit_jobs_to_results(jobs)
  snap <- structure(
    list(
      patience = patience,
      substantive = audit$substantive %||% TRUE,
      collections = audit$collections %||% NULL,
      started_at = started_at,
      finished_at = finished_at,
      results = results,
      summary = sm
    ),
    class = "audit_everything"
  )
  saveRDS(snap, rds_path)

  # Invalidate session cache used by Shiny / runtime lookups.
  if (exists(".registry_audit_cache", inherits = TRUE)) {
    cache <- get(".registry_audit_cache", inherits = TRUE)
    if (is.environment(cache)) {
      rm(list = ls(cache, all.names = TRUE), envir = cache)
    }
  }

  invisible(list(
    summary = summary_path,
    rds = rds_path,
    jobs = registry_audit_jobs_path(registry_root)
  ))
}

#' Rebuild \code{audit_summary.json} from the full audit jobs CSV
#'
#' Does not re-run audits. Use after manual CSV edits or after
#' [seed_registry_audit_jobs()].
#'
#' @param registry_root Optional registry repository root.
#' @return Invisibly, a list with paths \code{summary}, \code{rds}, \code{jobs}.
#' @examples
#' \dontrun{
#' refresh_registry_audit_summary(registry_root = "registry")
#' }
#' @export
refresh_registry_audit_summary <- function(registry_root = NULL) {
  if (!is.null(registry_root) && nzchar(registry_root) && dir.exists(registry_root)) {
    options(
      replicateEverything.registry_root = normalizePath(
        registry_root,
        winslash = "/",
        mustWork = FALSE
      )
    )
  }
  jobs <- read_registry_audit_jobs(registry_root)
  write_derived_registry_audit_summary(jobs, audit = NULL, registry_root = registry_root)
}

#' Seed / refresh audit jobs CSV from bake timings, artifacts, and prior RDS
#'
#' Populates missing study×step rows so the health bar is not empty before the
#' first full portfolio audit. Existing \code{source = "audit"} rows are kept;
#' bake/artifact rows only fill gaps (or refresh provisional bake rows).
#'
#' @param registry_root Optional registry root.
#' @param index Optional registry index (default [load_index()]).
#' @param from_rds If \code{TRUE}, migrate rows from \code{audit_latest.rds}
#'   when present.
#' @param from_bake If \code{TRUE}, add provisional ok rows from bake timings /
#'   local artifacts for jobs not yet in the CSV.
#' @param verbose Print progress.
#' @return Invisibly, list with \code{jobs} path, row counts, and summary paths.
#' @examples
#' \dontrun{
#' seed_registry_audit_jobs(registry_root = "registry")
#' }
#' @export
seed_registry_audit_jobs <- function(
  registry_root = NULL,
  index = NULL,
  from_rds = TRUE,
  from_bake = TRUE,
  verbose = TRUE
) {
  if (!is.null(registry_root) && nzchar(registry_root) && dir.exists(registry_root)) {
    options(
      replicateEverything.registry_root = normalizePath(
        registry_root,
        winslash = "/",
        mustWork = FALSE
      )
    )
    monorepo <- normalizePath(
      file.path(registry_root, ".."),
      winslash = "/",
      mustWork = FALSE
    )
    if (file.exists(file.path(monorepo, "registry", "index.csv"))) {
      tryCatch(configure_local_monorepo(monorepo), error = function(e) NULL)
    }
  }

  existing <- read_registry_audit_jobs(registry_root)
  n_before <- nrow(existing)
  checked <- audit_jobs_format_time(Sys.time())

  # 1) Migrate prior RDS results (audit provenance).
  if (isTRUE(from_rds)) {
    rds_path <- registry_audit_rds_path(registry_root)
    if (nzchar(rds_path) && file.exists(rds_path)) {
      snap <- tryCatch(readRDS(rds_path), error = function(e) NULL)
      if (!is.null(snap) && is.data.frame(snap$results) && nrow(snap$results) > 0L) {
        if (isTRUE(verbose)) {
          message("Seeding audit_jobs.csv from audit_latest.rds (", nrow(snap$results), " rows)")
        }
        rds_rows <- audit_results_to_jobs_rows(
          snap$results,
          checked_at = snap$finished_at %||% checked,
          source = "audit",
          prior_jobs = existing
        )
        existing <- upsert_registry_audit_jobs(rds_rows, registry_root)
      }
    }
  }

  # 2) Bake / artifact provisional rows for gaps.
  if (isTRUE(from_bake)) {
    if (is.null(index)) {
      index <- tryCatch(load_index(), error = function(e) NULL)
    }
    if (!is.null(index) && nrow(index) > 0L) {
      if (isTRUE(verbose)) {
        message("Seeding missing jobs from bake timings / artifacts")
      }
      bake_rows <- list()
      exist_keys <- audit_jobs_row_key(
        existing$doi,
        existing$object,
        existing$engine
      )
      for (i in seq_len(nrow(index))) {
        row <- index[i, , drop = FALSE]
        doi_raw <- as.character(row$doi[[1]] %||% "")
        doi <- if (nzchar(trimws(doi_raw))) {
          tryCatch(normalize_doi(doi_raw), error = function(e) doi_raw)
        } else if ("handle" %in% names(row)) {
          as.character(row$handle[[1]] %||% "")
        } else {
          ""
        }
        title <- as.character(row$title[[1]] %||% doi)
        folder <- if ("folder" %in% names(row)) {
          as.character(row$folder[[1]] %||% "")
        } else {
          ""
        }
        repo <- if ("repo" %in% names(row)) row$repo[[1]] else NULL

        reps <- tryCatch(
          list_replications(doi, repo = repo, folder = folder, include = "all"),
          error = function(e) NULL
        )
        if (is.null(reps)) {
          next
        }
        jobs <- tryCatch(
          audit_jobs_from_replications(reps),
          error = function(e) NULL
        )
        if (is.null(jobs) || nrow(jobs) == 0L) {
          next
        }

        study_root <- tryCatch(
          resolve_local_study_folder(doi),
          error = function(e) NULL
        )
        if (is.null(study_root) && nzchar(folder)) {
          folders_root <- getOption("replicateEverything.study_folders_root", NULL)
          if (!is.null(folders_root)) {
            cand <- file.path(folders_root, folder)
            if (dir.exists(cand)) {
              study_root <- cand
            }
          }
        }

        for (j in seq_len(nrow(jobs))) {
          job <- jobs[j, , drop = FALSE]
          what <- as.character(job$what[[1]] %||% "")
          engine <- as.character(job$engine[[1]] %||% "")
          label <- as.character(job$label[[1]] %||% what)
          type <- as.character(job$type[[1]] %||% "")
          skip_reason <- if ("skip_reason" %in% names(job)) {
            as.character(job$skip_reason[[1]] %||% "")
          } else {
            ""
          }
          key <- audit_jobs_row_key(doi, what, engine)
          if (key %in% exist_keys) {
            next
          }

          if (nzchar(skip_reason)) {
            err <- audit_error_snippet(skip_reason)
            cat <- audit_progress_category(
              skipped = TRUE,
              error_snippet = err
            )
            bake_rows[[length(bake_rows) + 1L]] <- data.frame(
              doi = doi,
              folder = folder,
              title = title,
              object = what,
              object_label = label,
              type = type,
              engine = engine,
              success = NA,
              run_ok = NA,
              substantive_ok = NA,
              seconds = NA_real_,
              runtime_category = NA_character_,
              timed_out = FALSE,
              skipped = TRUE,
              timeout_seconds = NA_real_,
              error_snippet = err,
              progress_category = cat,
              last_checked_at = checked,
              last_success_at = NA_character_,
              source = "yaml_skip",
              stringsAsFactors = FALSE
            )
            exist_keys <- c(exist_keys, key)
            next
          }

          bake_at <- audit_job_bake_success_at(
            doi,
            what,
            engine = engine,
            repo = repo,
            folder = folder,
            study_root = study_root
          )
          bake_secs <- tryCatch(
            lookup_study_replication_timing(study_root, what),
            error = function(e) NA_real_
          )
          has_bake <- (!is.na(bake_at) && nzchar(bake_at)) ||
            (is.finite(bake_secs) && bake_secs >= 0)

          if (!isTRUE(has_bake)) {
            next
          }

          bake_rows[[length(bake_rows) + 1L]] <- data.frame(
            doi = doi,
            folder = folder,
            title = title,
            object = what,
            object_label = label,
            type = type,
            engine = engine,
            success = TRUE,
            run_ok = TRUE,
            substantive_ok = NA,
            seconds = if (is.finite(bake_secs)) bake_secs else NA_real_,
            runtime_category = audit_runtime_category(bake_secs),
            timed_out = FALSE,
            skipped = FALSE,
            timeout_seconds = NA_real_,
            error_snippet = "",
            progress_category = "replicating",
            last_checked_at = checked,
            last_success_at = if (!is.na(bake_at) && nzchar(bake_at)) {
              bake_at
            } else {
              checked
            },
            source = "bake",
            stringsAsFactors = FALSE
          )
          exist_keys <- c(exist_keys, key)
        }
      }

      if (length(bake_rows) > 0L) {
        bake_df <- normalize_audit_jobs_df(do.call(rbind, bake_rows))
        if (isTRUE(verbose)) {
          message("Adding ", nrow(bake_df), " bake/artifact provisional job rows")
        }
        # Direct merge without re-deriving via audit_results_to_jobs_rows
        # (would overwrite source / success semantics).
        exist_now <- read_registry_audit_jobs(registry_root)
        exist_keys_now <- audit_jobs_row_key(
          exist_now$doi,
          exist_now$object,
          exist_now$engine
        )
        new_keys <- audit_jobs_row_key(bake_df$doi, bake_df$object, bake_df$engine)
        keep <- exist_now[!exist_keys_now %in% new_keys, , drop = FALSE]
        merged <- rbind(keep, bake_df)
        rownames(merged) <- NULL
        ord <- order(
          as.character(merged$doi),
          as.character(merged$object),
          as.character(merged$engine)
        )
        existing <- merged[ord, , drop = FALSE]
        write_registry_audit_jobs(existing, registry_root)
      }
    }
  }

  paths <- refresh_registry_audit_summary(registry_root)
  jobs_final <- read_registry_audit_jobs(registry_root)
  if (isTRUE(verbose)) {
    message(
      "audit_jobs.csv: ", n_before, " -> ", nrow(jobs_final), " rows; ",
      "summary: ", paths$summary
    )
  }
  invisible(list(
    jobs = paths$jobs,
    summary = paths$summary,
    rds = paths$rds,
    rows_before = n_before,
    rows_after = nrow(jobs_final)
  ))
}

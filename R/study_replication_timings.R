#' Study-local bake timings (`outputs/replication_timings.json`)
#'
#' Successful [run_replication()] / bake runs append elapsed seconds per step so
#' audit timeouts and Shiny hourglass warnings can report the last known
#' completion time instead of only the audit patience cap.
#'
#' @name study_replication_timings
#' @keywords internal
NULL

#' Path to study bake-timings JSON
#' @param study_root Study repository root.
#' @return Character path (`outputs/replication_timings.json`).
#' @keywords internal
study_replication_timings_path <- function(study_root) {
  file.path(as.character(study_root[[1]]), "outputs", "replication_timings.json")
}

#' Read study bake timings
#'
#' @param study_root Study repository root (or NULL to return empty).
#' @return List with \code{generated_at} and \code{steps} (named list of
#'   records with at least \code{seconds}).
#' @keywords internal
read_study_replication_timings <- function(study_root) {
  empty <- list(generated_at = NULL, steps = list())
  if (is.null(study_root) || !nzchar(as.character(study_root[[1]] %||% ""))) {
    return(empty)
  }
  path <- study_replication_timings_path(study_root)
  if (!file.exists(path)) {
    return(empty)
  }
  raw <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(raw)) {
    return(empty)
  }
  steps <- raw$steps %||% list()
  if (!is.list(steps)) {
    steps <- list()
  }
  list(
    generated_at = raw$generated_at %||% NULL,
    steps = steps
  )
}

#' Look up last known bake seconds for a step id
#'
#' @param study_root Study root.
#' @param step_id Step / replication id.
#' @return Numeric seconds, or \code{NA_real_} when unknown.
#' @keywords internal
lookup_study_replication_timing <- function(study_root, step_id) {
  step_id <- as.character(step_id[[1L]] %||% "")
  if (!nzchar(step_id)) {
    return(NA_real_)
  }
  timings <- read_study_replication_timings(study_root)
  rec <- timings$steps[[step_id]]
  if (is.null(rec)) {
    return(NA_real_)
  }
  secs <- as.numeric(rec$seconds %||% rec$elapsed_seconds %||% NA_real_)
  if (!is.finite(secs) || secs < 0) {
    return(NA_real_)
  }
  secs
}

#' Record a successful bake / run timing for one step
#'
#' Writes (or updates) \code{outputs/replication_timings.json} under the study
#' root. Safe to call from bake helpers; failures are swallowed so they never
#' break a successful replication.
#'
#' @param study_root Study repository root.
#' @param step_id Step id.
#' @param seconds Elapsed seconds.
#' @param engine Optional engine label.
#' @param status Optional status string (default \code{"ok"}).
#' @return Invisibly, the path written (or \code{NULL} on skip/failure).
#' @keywords internal
record_study_replication_timing <- function(
  study_root,
  step_id,
  seconds,
  engine = NULL,
  status = "ok"
) {
  root <- as.character(study_root[[1L]] %||% "")
  step_id <- as.character(step_id[[1L]] %||% "")
  seconds <- as.numeric(seconds[[1L]] %||% NA_real_)
  if (!nzchar(root) || !dir.exists(root) || !nzchar(step_id)) {
    return(invisible(NULL))
  }
  if (!is.finite(seconds) || seconds < 0) {
    return(invisible(NULL))
  }
  out_dir <- file.path(root, "outputs")
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  }
  path <- study_replication_timings_path(root)
  timings <- tryCatch(
    read_study_replication_timings(root),
    error = function(e) list(generated_at = NULL, steps = list())
  )
  rec <- list(
    seconds = round(seconds, 3),
    status = as.character(status[[1L]] %||% "ok"),
    recorded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  eng <- trimws(as.character(engine[[1L]] %||% ""))
  if (nzchar(eng)) {
    rec$engine <- eng
  }
  timings$steps[[step_id]] <- rec
  timings$generated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  # Atomic write: Dropbox-paused / locked destination can make a direct
  # write_json fail silently under the old tryCatch; stage to a sibling temp
  # then rename so a successful bake always leaves a readable timings file.
  tmp <- paste0(path, ".tmp")
  ok <- tryCatch({
    jsonlite::write_json(
      timings,
      tmp,
      auto_unbox = TRUE,
      pretty = TRUE,
      null = "null"
    )
    if (file.exists(path)) {
      unlink(path)
    }
    file.rename(tmp, path) || {
      file.copy(tmp, path, overwrite = TRUE)
      unlink(tmp)
      file.exists(path)
    }
  }, error = function(e) {
    if (file.exists(tmp)) {
      unlink(tmp)
    }
    warning(
      "record_study_replication_timing: could not write ", path, ": ",
      conditionMessage(e),
      call. = FALSE
    )
    FALSE
  })
  invisible(if (isTRUE(ok)) path else NULL)
}

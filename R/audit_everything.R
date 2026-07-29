#' Infer replication engine from a registry entry
#' @keywords internal
audit_replication_engine <- function(rep) {
  eng <- tolower(as.character(rep$engine %||% ""))
  if (identical(eng, "stata")) {
    return("stata")
  }
  if (identical(eng, "python") || identical(eng, "py")) {
    return("python")
  }
  if (identical(eng, "r")) {
    return("r")
  }
  id <- as.character(rep$id %||% "")
  if (grepl("_stata$", id, ignore.case = TRUE)) {
    return("stata")
  }
  code <- as.character(rep$code %||% "")
  if (length(code) == 1L && grepl("\\.do$", code, ignore.case = TRUE)) {
    return("stata")
  }
  if (length(code) == 1L && grepl("\\.(py|ipynb)$", code, ignore.case = TRUE)) {
    return("python")
  }
  "r"
}

#' Display label for a replication entry
#' @keywords internal
audit_replication_label <- function(rep) {
  label <- rep$label %||% rep$description %||% rep$id
  as.character(label[[1]] %||% label)
}

#' Group id for paired R / Stata replications
#' @keywords internal
audit_replication_group <- function(rep) {
  grp <- as.character(rep$group %||% "")
  if (nzchar(grp)) {
    return(grp)
  }
  as.character(rep$id %||% "")
}

#' Whether a proprietary / system engine is available on PATH
#'
#' Light probe only (no installs). Ordinary engines (R / Stata / Python) are
#' treated as available here; their absence is handled by the usual run path.
#' @keywords internal
system_engine_available <- function(display_name) {
  nm <- tolower(trimws(as.character(display_name[[1]] %||% display_name)))
  if (!nzchar(nm)) {
    return(TRUE)
  }
  if (nm %in% c("mathematica", "wolfram")) {
    return(
      nzchar(Sys.which("wolframscript")) ||
        nzchar(Sys.which("MathKernel")) ||
        nzchar(Sys.which("math"))
    )
  }
  if (identical(nm, "matlab")) {
    return(nzchar(Sys.which("matlab")))
  }
  if (identical(nm, "julia")) {
    return(nzchar(Sys.which("julia")))
  }
  TRUE
}

#' Reason an audit job should be recorded as skipped (not executed)
#'
#' Skips yaml \code{incomplete: true} steps (including \code{requires_engine:}
#' and \code{data_unavailable:} gaps), and steps that declare a missing
#' proprietary/system engine even when \code{incomplete} was omitted.
#' @keywords internal
audit_step_skip_reason <- function(rep) {
  if (!is.list(rep)) {
    return(NULL)
  }
  label <- audit_replication_label(rep)
  if (!nzchar(label)) {
    label <- as.character(rep$id %||% "Step")
  }

  if (isTRUE(rep$incomplete %||% FALSE)) {
    eng <- step_required_engine(rep)
    if (!is.null(eng)) {
      return(missing_engine_message(label, eng, mode = "not_available"))
    }
    data_tok <- step_data_unavailable(rep)
    if (!is.null(data_tok)) {
      return(missing_data_message(label, data_tok, mode = "not_available"))
    }
    reason <- as.character(rep$blocked_reason %||% "")
    if (!nzchar(reason)) {
      reason <- "marked incomplete in replication.yml (no reason given)"
    }
    return(paste0(label, " not available because of: ", reason))
  }

  eng <- step_required_engine(rep)
  if (!is.null(eng) && !eng %in% c("R", "Stata", "Python") &&
      !isTRUE(system_engine_available(eng))) {
    return(missing_engine_message(label, eng, mode = "not_available"))
  }
  NULL
}

#' User-facing status label for one audit result row
#'
#' Maps success / timeout / skipped flags to `"OK"`, `"Timed out"`,
#' `"Failed"`, or `"Skipped"`. Used by registry audit reports and the
#' package audit vignette.
#'
#' @param success Logical vector of success flags (`NA` allowed).
#' @param timed_out Logical vector of timeout flags.
#' @param skipped Logical vector of skip flags (incomplete / blocked steps).
#' @return Character vector of status labels, same length as the inputs.
#' @export
audit_result_status <- function(success, timed_out = FALSE, skipped = FALSE) {
  n <- max(length(success), length(timed_out), length(skipped), 1L)
  success <- rep_len(success, n)
  timed_out <- rep_len(timed_out, n)
  skipped <- rep_len(skipped, n)
  out <- character(n)
  for (i in seq_len(n)) {
    if (isTRUE(skipped[[i]])) {
      out[[i]] <- "Skipped"
    } else if (isTRUE(success[[i]])) {
      out[[i]] <- "OK"
    } else if (isTRUE(timed_out[[i]])) {
      out[[i]] <- "Timed out"
    } else {
      out[[i]] <- "Failed"
    }
  }
  out
}

#' Progress-bar category for one audit result row
#'
#' Mutually exclusive buckets for the Shiny registry health bar:
#' \code{replicating}, \code{timed_out}, \code{substantive_fail},
#' \code{missing_engine}, or \code{other} (gaps / skipped / incomplete /
#' data unavailable / other fails).
#'
#' @param success Logical success flag (`NA` allowed for skipped rows).
#' @param timed_out Logical timeout flag.
#' @param skipped Logical skip flag.
#' @param substantive_ok Logical or \code{NA} substantive-check result.
#' @param error_snippet Character skip / error reason.
#' @return Character scalar category id.
#' @keywords internal
audit_progress_category <- function(
  success = NA,
  timed_out = FALSE,
  skipped = FALSE,
  substantive_ok = NA,
  error_snippet = ""
) {
  if (isTRUE(skipped)) {
    if (isTRUE(audit_reason_is_missing_engine(error_snippet))) {
      return("missing_engine")
    }
    return("other")
  }
  if (isTRUE(timed_out)) {
    return("timed_out")
  }
  if (isFALSE(substantive_ok)) {
    return("substantive_fail")
  }
  if (isTRUE(success)) {
    return("replicating")
  }
  "other"
}

#' Vectorized progress categories for an audit results data frame
#' @keywords internal
audit_progress_categories_from_results <- function(results) {
  if (is.null(results) || !is.data.frame(results) || nrow(results) == 0L) {
    return(character(0))
  }
  n <- nrow(results)
  success <- if ("success" %in% names(results)) results$success else rep(NA, n)
  timed_out <- if ("timed_out" %in% names(results)) {
    results$timed_out
  } else {
    rep(FALSE, n)
  }
  skipped <- if ("skipped" %in% names(results)) {
    results$skipped
  } else {
    rep(FALSE, n)
  }
  substantive_ok <- if ("substantive_ok" %in% names(results)) {
    results$substantive_ok
  } else {
    rep(NA, n)
  }
  snippet <- if ("error_snippet" %in% names(results)) {
    as.character(results$error_snippet)
  } else {
    rep("", n)
  }
  vapply(seq_len(n), function(i) {
    audit_progress_category(
      success = success[[i]],
      timed_out = timed_out[[i]],
      skipped = skipped[[i]],
      substantive_ok = substantive_ok[[i]],
      error_snippet = snippet[[i]]
    )
  }, character(1))
}

#' Named progress counts for the registry health bar
#'
#' Prefers classifying rows from a full audit results data frame. When only a
#' summary list is available, reconstructs counts from summary fields
#' (\code{success}, \code{timed_out}, \code{substantive_failed},
#' \code{missing_engine}, \code{failed}, \code{skipped}).
#'
#' @param summary Optional audit summary list (from \code{audit_summary.json}).
#' @param results Optional audit results data frame.
#' @return Named integer vector with categories
#'   \code{replicating}, \code{timed_out}, \code{substantive_fail},
#'   \code{missing_engine}, \code{other}, plus \code{total}.
#' @keywords internal
audit_progress_counts <- function(summary = NULL, results = NULL) {
  empty <- c(
    replicating = 0L,
    timed_out = 0L,
    substantive_fail = 0L,
    missing_engine = 0L,
    other = 0L,
    total = 0L
  )
  if (!is.null(results) && is.data.frame(results) && nrow(results) > 0L) {
    cats <- audit_progress_categories_from_results(results)
    tab <- table(factor(cats, levels = names(empty)[names(empty) != "total"]))
    out <- empty
    out[names(tab)] <- as.integer(tab)
    out[["total"]] <- length(cats)
    return(out)
  }
  if (is.null(summary) || !is.list(summary)) {
    return(empty)
  }
  # Prefer baked progress from audit_summary.json (Shiny health bar path).
  prog <- summary$progress %||% NULL
  if (is.list(prog) && length(prog)) {
    out <- empty
    for (nm in names(empty)) {
      if (nm %in% names(prog)) {
        val <- as.integer(prog[[nm]][[1]] %||% prog[[nm]] %||% 0L)
        if (length(val) == 1L && !is.na(val)) {
          out[[nm]] <- max(0L, val)
        }
      }
    }
    if (out[["total"]] <= 0L) {
      out[["total"]] <- sum(out[names(out) != "total"])
    }
    if (sum(out[names(out) != "total"]) > 0L || out[["total"]] > 0L) {
      return(out)
    }
  }
  n_ok <- as.integer(summary$success %||% 0L)
  n_timeout <- as.integer(summary$timed_out %||% 0L)
  n_sub <- as.integer(summary$substantive_failed %||% 0L)
  n_miss <- as.integer(summary$missing_engine %||% 0L)
  n_fail <- as.integer(summary$failed %||% 0L)
  n_skip <- as.integer(summary$skipped %||% 0L)
  n_runs <- as.integer(summary$runs %||% 0L)

  other_fails <- max(0L, n_fail - n_timeout - n_sub)
  other_skips <- max(0L, n_skip - n_miss)
  out <- empty
  out[["replicating"]] <- max(0L, n_ok)
  out[["timed_out"]] <- max(0L, n_timeout)
  out[["substantive_fail"]] <- max(0L, n_sub)
  out[["missing_engine"]] <- max(0L, n_miss)
  out[["other"]] <- other_fails + other_skips
  out[["total"]] <- if (is.finite(n_runs) && n_runs > 0L) {
    n_runs
  } else {
    sum(out[names(out) != "total"])
  }
  out
}

#' Format an audit timeout error for reports
#'
#' @param patience Seconds used as the audit elapsed-time cap.
#' @param detail Optional underlying error text (kept short when present).
#' @return Character scalar for the Error column.
#' @keywords internal
audit_timeout_message <- function(patience, detail = NULL) {
  patience <- as.numeric(patience[[1]] %||% patience)
  if (!is.finite(patience) || patience <= 0) {
    patience <- NA_real_
  }
  cap <- if (is.finite(patience)) {
    sprintf(
      "Timed out after %.0f seconds (audit cap; timeout_seconds: %.0f)",
      patience,
      patience
    )
  } else {
    "Timed out (audit cap)"
  }
  detail <- trimws(as.character(detail %||% ""))
  if (!nzchar(detail)) {
    return(cap)
  }
  # Avoid duplicating the cap phrase if the detail already names it
  if (grepl("audit cap|timeout_seconds", detail, ignore.case = TRUE)) {
    return(audit_error_snippet(detail))
  }
  paste0(cap, " | ", audit_error_snippet(detail, max_chars = 160L))
}

#' List audit jobs (one row per engine) from replication entries
#'
#' Incomplete / blocked steps are included with a non-empty \code{skip_reason}
#' so the audit can record them as \strong{Skipped} without executing them.
#' Runnable jobs are display steps (figure / table) only.
#'
#' @param reps List of replication entries from \code{list_replications()}.
#' @return Data frame with columns \code{group}, \code{what}, \code{engine},
#'   \code{label}, \code{type}, and \code{skip_reason}.
#' @keywords internal
audit_jobs_from_replications <- function(reps) {
  if (is.null(reps) || !length(reps)) {
    return(NULL)
  }

  reps <- reps[vapply(reps, function(x) {
    is.list(x) && !is.null(x$id) && nzchar(as.character(x$id[[1]] %||% x$id))
  }, logical(1))]
  reps <- reps[vapply(reps, function(x) {
    type <- tolower(as.character(x$type %||% ""))
    type %in% c("figure", "table", "step", "prep", "pipeline", "transform")
  }, logical(1))]
  if (!length(reps)) {
    return(NULL)
  }

  groups <- unique(vapply(reps, audit_replication_group, character(1)))
  rows <- lapply(groups, function(group) {
    group_reps <- reps[vapply(reps, function(x) {
      identical(audit_replication_group(x), group)
    }, logical(1))]
    jobs <- list()
    for (eng in c("r", "stata", "python")) {
      eng_reps <- group_reps[vapply(group_reps, function(x) {
        identical(audit_replication_engine(x), eng)
      }, logical(1))]
      if (!length(eng_reps)) {
        next
      }
      rep <- eng_reps[[1]]
      skip_reason <- audit_step_skip_reason(rep)
      type <- tolower(as.character(rep$type %||% ""))
      # Runnable audit targets remain display sinks; blocked pipeline / transform
      # steps are still listed so they appear as Skipped rather than vanishing.
      if (is.null(skip_reason) && !type %in% c("figure", "table")) {
        next
      }
      jobs[[length(jobs) + 1L]] <- data.frame(
        group = group,
        what = as.character(rep$id),
        engine = eng,
        label = audit_replication_label(rep),
        type = as.character(rep$type %||% ""),
        skip_reason = if (is.null(skip_reason)) {
          NA_character_
        } else {
          as.character(skip_reason)
        },
        stringsAsFactors = FALSE
      )
    }
    if (!length(jobs)) {
      return(NULL)
    }
    do.call(rbind, jobs)
  })

  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(NULL)
  }
  do.call(rbind, rows)
}

#' Rough runtime category thresholds (seconds)
#'
#' \itemize{
#'   \item \code{short} — under 30 seconds
#'   \item \code{medium} — 30 seconds up to 5 minutes
#'   \item \code{slow} — over 5 minutes
#' }
#' @keywords internal
AUDIT_RUNTIME_SHORT_MAX <- 30
AUDIT_RUNTIME_MEDIUM_MAX <- 300

#' Bucket audit elapsed seconds into short / medium / slow
#'
#' @param seconds Numeric elapsed seconds (scalar or vector; \code{NA} allowed).
#' @return Character vector of categories (\code{"short"}, \code{"medium"},
#'   \code{"slow"}), or \code{NA_character_} when \code{seconds} is missing.
#' @keywords internal
audit_runtime_category <- function(seconds) {
  seconds <- as.numeric(seconds)
  out <- rep(NA_character_, length(seconds))
  ok <- is.finite(seconds) & !is.na(seconds) & seconds >= 0
  out[ok & seconds < AUDIT_RUNTIME_SHORT_MAX] <- "short"
  out[ok & seconds >= AUDIT_RUNTIME_SHORT_MAX & seconds < AUDIT_RUNTIME_MEDIUM_MAX] <- "medium"
  out[ok & seconds >= AUDIT_RUNTIME_MEDIUM_MAX] <- "slow"
  out
}

#' Human-readable expected-time advice from an audit runtime category
#'
#' @param category \code{"short"}, \code{"medium"}, or \code{"slow"}.
#' @param seconds Optional elapsed seconds from the last audit for a more
#'   specific tip.
#' @return Character scalar (may be empty when category is missing).
#' @keywords internal
audit_runtime_advice <- function(category, seconds = NULL) {
  cat <- tolower(trimws(as.character(category[[1L]] %||% "")))
  secs <- if (!is.null(seconds) && length(seconds)) {
    as.numeric(seconds[[1L]])
  } else {
    NA_real_
  }
  # Sub-second audits are common; %.0f would round them to a misleading "0s".
  secs_note <- if (is.finite(secs) && secs >= 0) {
    if (secs < 1) {
      sprintf(" (last audit: %.1fs)", secs)
    } else if (secs < 60) {
      sprintf(" (last audit: %.0fs)", secs)
    } else if (secs < 3600) {
      sprintf(" (last audit: ~%.0f min)", secs / 60)
    } else {
      sprintf(" (last audit: ~%.1f h)", secs / 3600)
    }
  } else {
    ""
  }
  switch(
    cat,
    short = paste0("Expected time: typically seconds", secs_note, "."),
    medium = paste0("Expected time: about a minute or a few minutes", secs_note, "."),
    slow = paste0(
      "Expected time: several minutes or longer",
      secs_note,
      ". Consider leaving this tab open while it runs."
    ),
    ""
  )
}

#' Look up audit runtime for one study object
#'
#' Reads the registry \code{audit_latest.rds} snapshot when available and returns
#' elapsed seconds and a short/medium/slow category for Shiny Run advice.
#'
#' @param doi Study DOI.
#' @param what Replication id (or group id).
#' @param engine Optional engine filter (\code{"r"}, \code{"stata"}, \code{"python"}).
#' @param registry_root Optional registry root.
#' @return List with \code{available}, \code{seconds}, \code{runtime_category},
#'   \code{advice}, \code{timed_out}, \code{timeout_seconds}, and matching
#'   \code{object}.
#' @keywords internal
lookup_replication_audit_runtime <- function(
  doi,
  what,
  engine = NULL,
  registry_root = NULL,
  study_root = NULL
) {
  empty <- list(
    available = FALSE,
    seconds = NA_real_,
    runtime_category = NA_character_,
    advice = "",
    timed_out = FALSE,
    timeout_seconds = NA_real_,
    bake_seconds = NA_real_,
    object = NA_character_
  )
  snap <- tryCatch(
    load_registry_audit_snapshot(registry_root),
    error = function(e) NULL
  )
  if (is.null(snap) || is.null(snap$results) || !nrow(snap$results)) {
    # Still try bake timings when audit snapshot is missing.
    bake_seconds <- tryCatch(
      lookup_study_replication_timing(study_root, what),
      error = function(e) NA_real_
    )
    empty$bake_seconds <- bake_seconds
    return(empty)
  }
  doi_norm <- normalize_doi(doi)
  what <- as.character(what[[1L]] %||% what)
  results <- snap$results
  results$doi_norm <- vapply(results$doi, normalize_doi, character(1))
  sub <- results[results$doi_norm == doi_norm, , drop = FALSE]
  if (!nrow(sub)) {
    bake_seconds <- tryCatch(
      lookup_study_replication_timing(study_root, what),
      error = function(e) NA_real_
    )
    empty$bake_seconds <- bake_seconds
    return(empty)
  }
  objs <- as.character(sub$object)
  hit <- sub[objs == what, , drop = FALSE]
  if (!nrow(hit) && nzchar(what)) {
    hit <- sub[
      objs == paste0(what, "_stata") |
        objs == paste0(what, "_python") |
        startsWith(objs, paste0(what, "_")),
      ,
      drop = FALSE
    ]
  }
  eng <- tolower(trimws(as.character(engine[[1L]] %||% "")))
  if (nzchar(eng) && nrow(hit)) {
    eng_hit <- hit[tolower(as.character(hit$engine)) == eng, , drop = FALSE]
    if (nrow(eng_hit)) {
      hit <- eng_hit
    }
  }
  if (!nrow(hit)) {
    bake_seconds <- tryCatch(
      lookup_study_replication_timing(study_root, what),
      error = function(e) NA_real_
    )
    empty$bake_seconds <- bake_seconds
    return(empty)
  }
  # Prefer a successful timed run when multiple rows match; otherwise keep
  # timeout / failure rows so Shiny can surface long-run chrome.
  prefer <- hit
  if ("success" %in% names(prefer) && any(prefer$success %in% TRUE)) {
    prefer <- prefer[prefer$success %in% TRUE, , drop = FALSE]
  }
  row <- prefer[1L, , drop = FALSE]
  seconds <- as.numeric(row$seconds[[1L]])
  timed_out <- isTRUE(row$timed_out[[1L]])
  timeout_seconds <- if ("timeout_seconds" %in% names(row)) {
    as.numeric(row$timeout_seconds[[1L]])
  } else {
    NA_real_
  }
  if ((!is.finite(timeout_seconds) || timeout_seconds <= 0) &&
      isTRUE(timed_out) &&
      !is.null(snap$patience)) {
    timeout_seconds <- as.numeric(snap$patience[[1L]] %||% snap$patience)
  }
  bake_seconds <- tryCatch(
    lookup_study_replication_timing(study_root, what),
    error = function(e) NA_real_
  )
  if (!is.finite(bake_seconds) || bake_seconds <= 0) {
    # Fallback: monorepo sibling / study_folders_root + folder from DOI.
    bake_seconds <- tryCatch({
      folders_root <- getOption("replicateEverything.study_folders_root", NULL)
      folder <- tryCatch(
        study_folder_from_doi(doi),
        error = function(e) NULL
      )
      if (is.null(folders_root) || is.null(folder)) {
        NA_real_
      } else {
        lookup_study_replication_timing(file.path(folders_root, folder), what)
      }
    }, error = function(e) NA_real_)
  }
  # When audit timed out at the patience cap, prefer bake seconds for advice.
  advice_seconds <- seconds
  if (isTRUE(timed_out) && is.finite(bake_seconds) && bake_seconds > 0) {
    advice_seconds <- bake_seconds
  }
  category <- if (isTRUE(timed_out)) {
    "slow"
  } else if ("runtime_category" %in% names(row) &&
    nzchar(as.character(row$runtime_category[[1L]] %||% ""))) {
    as.character(row$runtime_category[[1L]])
  } else {
    audit_runtime_category(advice_seconds)
  }
  list(
    available = TRUE,
    seconds = seconds,
    runtime_category = category,
    advice = audit_runtime_advice(category, advice_seconds),
    timed_out = timed_out,
    timeout_seconds = timeout_seconds,
    bake_seconds = bake_seconds,
    object = as.character(row$object[[1L]] %||% what)
  )
}

#' Whether registry audit skipped a step for a missing-engine reason
#'
#' Used by Shiny to prefer audit signals for hammer Run-slot chrome when
#' display outputs are missing.
#'
#' @inheritParams lookup_replication_audit_runtime
#' @return List with \code{skipped_engine} and \code{reason}.
#' @keywords internal
lookup_replication_audit_engine_skip <- function(
  doi,
  what,
  engine = NULL,
  registry_root = NULL
) {
  empty <- list(skipped_engine = FALSE, reason = "")
  snap <- tryCatch(
    load_registry_audit_snapshot(registry_root),
    error = function(e) NULL
  )
  if (is.null(snap) || is.null(snap$results) || !nrow(snap$results)) {
    return(empty)
  }
  if (!("skipped" %in% names(snap$results))) {
    return(empty)
  }
  doi_norm <- normalize_doi(doi)
  what <- as.character(what[[1L]] %||% what)
  results <- snap$results
  results$doi_norm <- vapply(results$doi, normalize_doi, character(1))
  sub <- results[results$doi_norm == doi_norm, , drop = FALSE]
  if (!nrow(sub)) {
    return(empty)
  }
  objs <- as.character(sub$object)
  hit <- sub[objs == what, , drop = FALSE]
  if (!nrow(hit) && nzchar(what)) {
    hit <- sub[
      objs == paste0(what, "_stata") |
        objs == paste0(what, "_python") |
        startsWith(objs, paste0(what, "_")),
      ,
      drop = FALSE
    ]
  }
  eng <- tolower(trimws(as.character(engine[[1L]] %||% "")))
  if (nzchar(eng) && nrow(hit)) {
    eng_hit <- hit[tolower(as.character(hit$engine)) == eng, , drop = FALSE]
    if (nrow(eng_hit)) {
      hit <- eng_hit
    }
  }
  if (!nrow(hit)) {
    return(empty)
  }
  skipped <- hit[as.logical(hit$skipped) %in% TRUE, , drop = FALSE]
  if (!nrow(skipped)) {
    return(empty)
  }
  reason <- ""
  if ("error_snippet" %in% names(skipped)) {
    reason <- as.character(skipped$error_snippet[[1L]] %||% "")
  }
  if (!nzchar(reason) && "skip_reason" %in% names(skipped)) {
    reason <- as.character(skipped$skip_reason[[1L]] %||% "")
  }
  list(
    skipped_engine = audit_reason_is_missing_engine(reason) ||
      grepl("mathematica|wolfram|matlab|julia", reason, ignore.case = TRUE),
    reason = reason
  )
}

#' Truncate an error message for audit output
#' @keywords internal
audit_error_snippet <- function(x, max_chars = 240L) {
  msg <- replication_error_message(x)
  msg <- gsub("\r\n", "\n", msg, fixed = TRUE)
  msg <- trimws(msg)
  msg <- gsub("[ \t]+", " ", msg)
  msg <- gsub("\n+", " | ", msg)
  if (nchar(msg) <= max_chars) {
    return(msg)
  }
  paste0(substr(msg, 1, max_chars), "...")
}

#' Run one replication with a per-object time limit
#'
#' @inheritParams render_replication
#' @param patience Seconds before halting the run (default 20). This is the
#'   audit cap applied via \code{setTimeLimit}; for Stata, the processx wait is
#'   also aligned to this cap so overdue batch jobs are killed cleanly.
#' @return List with \code{success}, \code{seconds}, \code{timed_out},
#'   \code{timeout_seconds}, and \code{error}.
#' @keywords internal
audit_run_one <- function(
  doi,
  what,
  engine = NULL,
  patience = 120,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  substantive = TRUE
) {
  patience <- as.numeric(patience[[1]] %||% patience)
  if (!is.finite(patience) || patience <= 0) {
    stop("patience must be a positive number of seconds.", call. = FALSE)
  }

  # Align Stata processx waits with the audit cap (do not raise above patience).
  old_stata_timeout <- getOption("replicateEverything.stata_timeout", NULL)
  if (identical(tolower(as.character(engine[[1]] %||% "")), "stata")) {
    options(replicateEverything.stata_timeout = as.integer(ceiling(patience)))
    on.exit(
      options(replicateEverything.stata_timeout = old_stata_timeout),
      add = TRUE
    )
  }

  t0 <- proc.time()
  run <- tryCatch(
    {
      setTimeLimit(elapsed = patience, transient = TRUE)
      on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
      result <- render_replication(
        doi,
        what,
        language = engine,
        install_deps = install_deps,
        repo = repo,
        folder = folder
      )
      obj <- replication_object(result)
      if (is.null(obj)) {
        stop("Replication returned no object.", call. = FALSE)
      }
      list(ok = TRUE, error = NULL, object = obj)
    },
    error = function(e) {
      list(ok = FALSE, error = e, object = NULL)
    }
  )
  seconds <- (proc.time() - t0)[["elapsed"]]
  err_msg <- if (!is.null(run$error)) conditionMessage(run$error) else ""
  timed_out <- !isTRUE(run$ok) &&
    grepl(
      "elapsed time limit|cpu time limit|did not finish within",
      err_msg,
      ignore.case = TRUE
    )

  substantive_ok <- NA
  substantive_message <- ""
  if (isTRUE(run$ok) && isTRUE(substantive) && !is.null(run$object)) {
    sub <- run_substantive_check(
      run$object,
      doi = doi,
      what = what,
      repo = repo,
      folder = folder
    )
    if (isTRUE(sub$checked)) {
      substantive_ok <- isTRUE(sub$ok)
      substantive_message <- sub$message %||% ""
    }
  }

  overall_ok <- isTRUE(run$ok) &&
    (is.na(substantive_ok) || isTRUE(substantive_ok))

  list(
    success = overall_ok,
    run_ok = isTRUE(run$ok),
    substantive_ok = substantive_ok,
    substantive_message = substantive_message,
    seconds = seconds,
    timed_out = timed_out,
    timeout_seconds = patience,
    error = run$error
  )
}

#' Audit all registry replications
#'
#' Walks the replication registry and attempts every table and figure in each
#' available engine (R and Stata where defined). Failures do not stop the audit;
#' results are returned in a concise data frame. Yaml steps marked
#' \code{incomplete: true} (or blocked by a missing \code{requires_engine:} /
#' \code{data_unavailable:} gap) are recorded as \strong{Skipped} with a reason
#' and are not executed. Each runnable job is halted after \code{patience}
#' seconds (the audit cap); timeout rows record \code{timeout_seconds} and an
#' explicit audit-cap message. For a full HTML report, render
#' \code{audit_everything.qmd} in the
#' [registry repository](https://github.com/replicate-anything/registry) (see
#' [audit_everything_qmd()]).
#'
#' @param patience Seconds to allow each table or figure before halting that run.
#'   Defaults to \code{20}. Registry reports often use \code{60}.
#' @param index Registry index data frame; defaults to [load_index()].
#' @param dois Optional character vector of DOIs to audit. When \code{NULL},
#'   audits every row in \code{index} (after any \code{collections} filter).
#' @param collections Optional character vector of registry collection tags
#'   (e.g. \code{"APSR"}, \code{c("PED", "World Bank")}). Keeps index rows
#'   whose \code{collections} field contains at least one listed tag. Ignored
#'   when \code{NULL}.
#' @param install_deps Logical. Passed to [render_replication()].
#' @param verbose Logical. Print progress messages.
#' @param registry_root Optional path to the registry repository. When set,
#'   writes \code{audit_summary.json} (and \code{audit_latest.rds}) there after
#'   the audit completes.
#' @param substantive Logical. When \code{TRUE} (default), run published-value
#'   checks from \code{tests/substantive/<step_id>.R} when a study defines them.
#' @return An object of class \code{audit_everything} with components
#'   \code{results} (data frame), \code{summary}, and metadata.
#' @export
#'
#' @examples
#' \dontrun{
#' audit <- audit_everything(patience = 20, dois = "10.1177/00491241211036161")
#' audit <- audit_everything(patience = 20, collections = "APSR")
#' print(audit)
#' }
audit_everything <- function(
  patience = 20,
  index = NULL,
  dois = NULL,
  collections = NULL,
  install_deps = FALSE,
  verbose = TRUE,
  registry_root = NULL,
  substantive = TRUE
) {
  patience <- as.numeric(patience)
  if (!is.finite(patience) || patience <= 0) {
    stop("patience must be a positive number of seconds.", call. = FALSE)
  }

  if (!is.null(registry_root) && nzchar(registry_root) && dir.exists(registry_root)) {
    options(
      replicateEverything.registry_root = normalizePath(
        registry_root,
        winslash = "/",
        mustWork = FALSE
      )
    )
  }
  if (!isTRUE(getOption("replicateEverything.use_sibling_packages", FALSE))) {
    monorepo <- if (!is.null(registry_root) && dir.exists(registry_root)) {
      normalizePath(file.path(registry_root, ".."), winslash = "/", mustWork = FALSE)
    } else {
      auto_detect_monorepo_root()
    }
    if (
      !is.null(monorepo) &&
        file.exists(file.path(monorepo, "registry", "index.csv"))
    ) {
      tryCatch(configure_local_monorepo(monorepo), error = function(e) NULL)
    }
  }

  if (is.null(index)) {
    index <- load_index()
  }
  if (is.null(index) || nrow(index) == 0) {
    stop("Registry index is empty.", call. = FALSE)
  }

  if (!is.null(dois)) {
    dois_norm <- vapply(dois, normalize_doi, character(1))
    index_dois <- vapply(index$doi, normalize_doi, character(1))
    index <- index[index_dois %in% dois_norm, , drop = FALSE]
    if (nrow(index) == 0) {
      stop("No matching studies in registry index.", call. = FALSE)
    }
  }

  if (!is.null(collections)) {
    index <- filter_index_by_collections(index, collections)
    if (nrow(index) == 0) {
      stop(
        "No matching studies for collection(s): ",
        paste(unique(na.omit(as.character(collections))), collapse = ", "),
        call. = FALSE
      )
    }
  }

  collections_filter <- if (!is.null(collections)) {
    unique(na.omit(trimws(as.character(collections))))
  } else {
    NULL
  }

  started_at <- Sys.time()
  results <- list()

  for (i in seq_len(nrow(index))) {
    row <- index[i, , drop = FALSE]
    doi_raw <- as.character(row$doi[[1]] %||% "")
    doi <- if (nzchar(trimws(doi_raw))) {
      normalize_doi(doi_raw)
    } else if ("handle" %in% names(row) && nzchar(trimws(as.character(row$handle[[1]] %||% "")))) {
      as.character(row$handle[[1]])
    } else {
      normalize_doi(doi_raw)
    }
    title <- as.character(row$title[[1]] %||% doi)
    folder <- if ("folder" %in% names(row)) row$folder[[1]] else NULL
    repo <- if ("repo" %in% names(row)) row$repo[[1]] else NULL

    if (isTRUE(verbose)) {
      message(sprintf("[%d/%d] %s", i, nrow(index), title))
    }

    reps <- tryCatch(
      list_replications(doi, repo = repo, folder = folder, include = "all"),
      error = function(e) e
    )

    if (inherits(reps, "error")) {
      results[[length(results) + 1L]] <- data.frame(
        doi = doi,
        title = title,
        object = NA_character_,
        object_label = NA_character_,
        type = NA_character_,
        engine = NA_character_,
        success = FALSE,
        run_ok = FALSE,
        substantive_ok = NA,
        seconds = NA_real_,
        runtime_category = NA_character_,
        timed_out = FALSE,
        skipped = FALSE,
        timeout_seconds = as.numeric(patience),
        error_snippet = audit_error_snippet(reps),
        stringsAsFactors = FALSE
      )
      next
    }

    jobs <- audit_jobs_from_replications(reps)
    if (is.null(jobs) || nrow(jobs) == 0) {
      results[[length(results) + 1L]] <- data.frame(
        doi = doi,
        title = title,
        object = NA_character_,
        object_label = "(no tables, figures, or steps)",
        type = NA_character_,
        engine = NA_character_,
        success = FALSE,
        run_ok = FALSE,
        substantive_ok = NA,
        seconds = NA_real_,
        runtime_category = NA_character_,
        timed_out = FALSE,
        skipped = FALSE,
        timeout_seconds = as.numeric(patience),
        error_snippet = "No table, figure, or pipeline step replications listed for this study.",
        stringsAsFactors = FALSE
      )
      next
    }

    for (j in seq_len(nrow(jobs))) {
      job <- jobs[j, , drop = FALSE]
      what <- job$what[[1]]
      engine <- job$engine[[1]]
      label <- job$label[[1]]
      type <- job$type[[1]]
      skip_reason <- if ("skip_reason" %in% names(job)) {
        as.character(job$skip_reason[[1]] %||% "")
      } else {
        ""
      }
      if (is.na(skip_reason)) {
        skip_reason <- ""
      }

      if (nzchar(skip_reason)) {
        if (isTRUE(verbose)) {
          message(sprintf("  - %s (%s, %s) [skipped]", label, what, engine))
        }
        results[[length(results) + 1L]] <- data.frame(
          doi = doi,
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
          timeout_seconds = as.numeric(patience),
          error_snippet = audit_error_snippet(skip_reason),
          stringsAsFactors = FALSE
        )
        next
      }

      if (isTRUE(verbose)) {
        message(sprintf("  - %s (%s, %s)", label, what, engine))
      }

      run <- audit_run_one(
        doi,
        what,
        engine = engine,
        patience = patience,
        install_deps = install_deps,
        repo = repo,
        folder = folder,
        substantive = substantive
      )

      err_snippet <- if (run$success) {
        ""
      } else if (isTRUE(run$timed_out)) {
        audit_timeout_message(
          run$timeout_seconds %||% patience,
          if (!is.null(run$error)) conditionMessage(run$error) else NULL
        )
      } else if (isFALSE(run$substantive_ok) && isTRUE(run$run_ok)) {
        audit_error_snippet(run$substantive_message)
      } else {
        audit_error_snippet(run$error)
      }

      results[[length(results) + 1L]] <- data.frame(
        doi = doi,
        title = title,
        object = what,
        object_label = label,
        type = type,
        engine = engine,
        success = run$success,
        run_ok = run$run_ok,
        substantive_ok = run$substantive_ok,
        seconds = run$seconds,
        runtime_category = audit_runtime_category(run$seconds),
        timed_out = run$timed_out,
        skipped = FALSE,
        timeout_seconds = as.numeric(run$timeout_seconds %||% patience),
        error_snippet = err_snippet,
        stringsAsFactors = FALSE
      )
    }
  }

  results_df <- do.call(rbind, results)
  rownames(results_df) <- NULL
  if (!is.null(results_df) && nrow(results_df) > 0L) {
    if (!"runtime_category" %in% names(results_df)) {
      results_df$runtime_category <- audit_runtime_category(results_df$seconds)
    }
    if (!"skipped" %in% names(results_df)) {
      results_df$skipped <- FALSE
    }
    if (!"timeout_seconds" %in% names(results_df)) {
      results_df$timeout_seconds <- as.numeric(patience)
    }
  }

  finished_at <- Sys.time()
  n_ok <- sum(results_df$success %in% TRUE, na.rm = TRUE)
  n_skip <- sum(results_df$skipped %in% TRUE, na.rm = TRUE)
  n_fail <- sum(results_df$success %in% FALSE, na.rm = TRUE)
  n_timeout <- sum(results_df$timed_out %in% TRUE, na.rm = TRUE)
  n_substantive_fail <- sum(
    !is.na(results_df$substantive_ok) & !results_df$substantive_ok,
    na.rm = TRUE
  )
  progress_counts <- audit_progress_counts(results = results_df)
  n_missing_engine <- as.integer(progress_counts[["missing_engine"]] %||% 0L)

  meta_root <- registry_root %||% getOption("replicateEverything.registry_root", NULL)
  missing_source <- tryCatch(
    registry_source_repository_gaps(registry_root = meta_root, index = index),
    error = function(e) character(0)
  )

  out <- structure(
    list(
      patience = patience,
      substantive = substantive,
      collections = collections_filter,
      started_at = started_at,
      finished_at = finished_at,
      results = results_df,
      summary = list(
        studies = nrow(index),
        runs = nrow(results_df),
        success = n_ok,
        failed = n_fail,
        timed_out = n_timeout,
        skipped = n_skip,
        substantive_failed = n_substantive_fail,
        missing_engine = n_missing_engine,
        progress = as.list(progress_counts),
        missing_source_repository = missing_source
      )
    ),
    class = "audit_everything"
  )

  root <- registry_root %||% getOption("replicateEverything.registry_root", NULL)
  if (!is.null(root) && nzchar(root)) {
    tryCatch(
      write_registry_audit_record(out, registry_root = root),
      error = function(e) {
        if (isTRUE(verbose)) {
          warning("Could not write registry audit record: ", conditionMessage(e), call. = FALSE)
        }
      }
    )
  }

  out
}

#' @keywords internal
#' @exportS3Method print audit_everything
print.audit_everything <- function(x, ...) {
  sm <- x$summary
  substantive_line <- if (!is.null(sm$substantive_failed) && sm$substantive_failed > 0L) {
    sprintf(" | Substantive failed: %d", sm$substantive_failed)
  } else {
    ""
  }
  skipped_line <- if (!is.null(sm$skipped) && sm$skipped > 0L) {
    sprintf(" | Skipped: %d", sm$skipped)
  } else {
    ""
  }
  collections_line <- if (!is.null(x$collections) && length(x$collections) > 0L) {
    sprintf("Collections: %s | ", paste(x$collections, collapse = ", "))
  } else {
    ""
  }
  cat(
    "replicateEverything registry audit\n",
    sprintf(
      paste0(
        "%sPatience: %gs | Studies: %d | Runs: %d | OK: %d | Failed: %d | ",
        "Timed out: %d%s%s\n"
      ),
      collections_line,
      x$patience,
      sm$studies,
      sm$runs,
      sm$success,
      sm$failed,
      sm$timed_out,
      skipped_line,
      substantive_line
    ),
    sep = ""
  )
  missing_src <- sm$missing_source_repository %||% character(0)
  if (length(missing_src) > 0L) {
    cat(
      "Metadata gaps — missing paper.source_repository (",
      length(missing_src),
      "):\n",
      sep = ""
    )
    for (key in missing_src) {
      cat("  - ", key, "\n", sep = "")
    }
  }
  if (isTRUE(sm$skipped > 0L)) {
    cat("\nSkipped (incomplete / unavailable):\n")
    skips <- x$results[x$results$skipped %in% TRUE, , drop = FALSE]
    studies <- unique(skips$title)
    for (study in studies) {
      sf <- skips[skips$title == study, , drop = FALSE]
      cat(sprintf("  %s\n", study))
      for (k in seq_len(nrow(sf))) {
        row <- sf[k, , drop = FALSE]
        cat(sprintf(
          "    - %s (%s, %s): %s\n",
          row$object_label[[1]],
          row$object[[1]],
          row$engine[[1]],
          row$error_snippet[[1]]
        ))
      }
    }
  }
  if (sm$failed > 0L) {
    cat("\nFailures by study:\n")
    fails <- x$results[
      x$results$success %in% FALSE & !x$results$skipped %in% TRUE,
      ,
      drop = FALSE
    ]
    studies <- unique(fails$title)
    for (study in studies) {
      sf <- fails[fails$title == study, , drop = FALSE]
      cat(sprintf("  %s\n", study))
      for (k in seq_len(nrow(sf))) {
        row <- sf[k, , drop = FALSE]
        obj <- row$object[[1]]
        if (is.na(obj) || !nzchar(obj)) {
          cat(sprintf("    - %s\n", row$error_snippet[[1]]))
        } else {
          tag <- if (isTRUE(row$timed_out[[1]])) {
            cap <- row$timeout_seconds[[1]] %||% x$patience
            sprintf(" [timed out after %gs audit cap]", as.numeric(cap))
          } else if (isFALSE(row$substantive_ok[[1]]) && isTRUE(row$run_ok[[1]])) {
            " [substantive]"
          } else {
            ""
          }
          cat(sprintf(
            "    - %s (%s, %s)%s: %s\n",
            row$object_label[[1]],
            obj,
            row$engine[[1]],
            tag,
            row$error_snippet[[1]]
          ))
        }
      }
    }
  }
  invisible(x)
}

#' Path to the registry audit summary JSON
#'
#' @param registry_root Optional registry repository root.
#' @return Character path, or \code{""} if the registry root is unknown.
#' @keywords internal
registry_audit_summary_path <- function(registry_root = NULL) {
  root <- registry_root %||% getOption("replicateEverything.registry_root", NULL)
  if (is.null(root) || !nzchar(root)) {
    root <- auto_detect_registry_root()
  }
  if (is.null(root) || !nzchar(root)) {
    return("")
  }
  file.path(root, "audit_summary.json")
}

#' Path to the full registry audit RDS snapshot
#'
#' @param registry_root Optional registry repository root.
#' @return Character path, or \code{""} if the registry root is unknown.
#' @keywords internal
registry_audit_rds_path <- function(registry_root = NULL) {
  root <- registry_root %||% getOption("replicateEverything.registry_root", NULL)
  if (is.null(root) || !nzchar(root)) {
    root <- auto_detect_registry_root()
  }
  if (is.null(root) || !nzchar(root)) {
    return("")
  }
  file.path(root, "audit_latest.rds")
}

#' Write audit results into the registry repository
#'
#' Writes \code{audit_summary.json} for Shiny and lightweight consumers, and
#' \code{audit_latest.rds} with the full \code{audit_everything} object.
#'
#' @param audit An \code{audit_everything} object.
#' @param registry_root Registry repository root.
#' @return Invisibly, a list with paths \code{summary} and \code{rds}.
#' @keywords internal
write_registry_audit_record <- function(audit, registry_root = NULL) {
  summary_path <- registry_audit_summary_path(registry_root)
  rds_path <- registry_audit_rds_path(registry_root)
  if (!nzchar(summary_path)) {
    stop("Could not resolve registry root for audit record.", call. = FALSE)
  }

  sm <- audit$summary
  progress <- sm$progress %||% as.list(audit_progress_counts(
    summary = sm,
    results = audit$results
  ))
  payload <- list(
    patience = audit$patience,
    started_at = format(audit$started_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    finished_at = format(audit$finished_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    studies = sm$studies,
    runs = sm$runs,
    success = sm$success,
    failed = sm$failed,
    timed_out = sm$timed_out,
    skipped = sm$skipped %||% 0L,
    substantive_failed = sm$substantive_failed %||% 0L,
    missing_engine = sm$missing_engine %||% progress$missing_engine %||% 0L,
    progress = progress,
    missing_source_repository = as.list(sm$missing_source_repository %||% character(0))
  )
  jsonlite::write_json(
    payload,
    summary_path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )
  saveRDS(audit, rds_path)

  invisible(list(summary = summary_path, rds = rds_path))
}

#' Load the registry audit summary
#'
#' Reads \code{audit_summary.json} from a local registry checkout when
#' available; otherwise fetches from GitHub.
#'
#' @param registry_root Optional registry repository root.
#' @return A list with summary counts, or \code{NULL} when unavailable.
#' @keywords internal
load_registry_audit_summary <- function(registry_root = NULL) {
  path <- registry_audit_summary_path(registry_root)
  if (nzchar(path) && file.exists(path)) {
    return(jsonlite::fromJSON(path))
  }

  url <- paste0(
    "https://raw.githubusercontent.com/",
    DEFAULT_REGISTRY_REPO,
    "/main/audit_summary.json"
  )
  tryCatch(
    jsonlite::fromJSON(url),
    error = function(e) NULL
  )
}

#' Path to the registry Quarto audit report
#'
#' Returns \code{audit_everything.qmd} from a local registry checkout. Looks in
#' \code{registry_root}, \code{getOption("replicateEverything.registry_root")},
#' \code{auto_detect_registry_root()}, or a sibling \code{registry/} folder in a
#' monorepo.
#'
#' @param registry_root Optional path to the registry repository root.
#' @return Character path, or \code{""} if not found.
#' @keywords internal
audit_everything_qmd <- function(registry_root = NULL) {
  candidates <- character(0)
  if (!is.null(registry_root) && nzchar(registry_root)) {
    candidates <- c(candidates, registry_root)
  }
  opt <- getOption("replicateEverything.registry_root", NULL)
  if (!is.null(opt) && nzchar(opt)) {
    candidates <- c(candidates, opt)
  }
  detected <- auto_detect_registry_root()
  if (!is.null(detected) && nzchar(detected)) {
    candidates <- c(candidates, detected)
  }
  monorepo <- auto_detect_monorepo_root()
  if (!is.null(monorepo) && nzchar(monorepo)) {
    candidates <- c(candidates, file.path(monorepo, "registry"))
  }

  for (root in unique(candidates[nzchar(candidates)])) {
    path <- file.path(root, "audit_everything.qmd")
    if (file.exists(path)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }
  ""
}

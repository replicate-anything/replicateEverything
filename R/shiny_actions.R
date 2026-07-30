# Shared Shiny Display / Live Run bare operations
#
# Shiny app.R and shiny_verification.qmd call these so button semantics stay
# in lockstep: Display = prefer artifact, fallback_live = FALSE; Run = leaf-only
# prefer live with shiny_run / padlock / hammer / compat / estimate gates.

#' Estimate seconds for a Live Run from an audit runtime row
#'
#' Prefers last successful bake duration when the audit only hit the patience
#' cap; otherwise takes the max of bake / elapsed / timeout candidates.
#'
#' @param rt List from [lookup_replication_audit_runtime()] (or \code{NULL}).
#' @return Numeric scalar seconds, or \code{NA_real_}.
#' @keywords internal
shiny_runtime_estimate_seconds <- function(rt) {
  if (is.null(rt) || !is.list(rt)) {
    return(NA_real_)
  }
  bake <- suppressWarnings(as.numeric(
    rt$bake_seconds[[1L]] %||% rt$bake_seconds %||% NA_real_
  ))
  secs <- suppressWarnings(as.numeric(
    rt$seconds[[1L]] %||% rt$seconds %||% NA_real_
  ))
  cap <- suppressWarnings(as.numeric(
    rt$timeout_seconds[[1L]] %||% rt$timeout_seconds %||% NA_real_
  ))
  if (isTRUE(rt$timed_out) && is.finite(bake) && bake > 0) {
    return(bake)
  }
  cand <- c(bake, secs, cap)
  cand <- cand[is.finite(cand) & cand > 0]
  if (!length(cand)) {
    return(NA_real_)
  }
  max(cand)
}

#' Format a short duration for Live Run estimate gates
#'
#' @param seconds Numeric seconds.
#' @return Character scalar.
#' @keywords internal
format_run_duration_short <- function(seconds) {
  seconds <- suppressWarnings(as.numeric(seconds[[1L]] %||% seconds))
  if (!is.finite(seconds) || seconds <= 0) {
    return("an extended run")
  }
  if (seconds < 90) {
    return(sprintf("about %.0f seconds", seconds))
  }
  if (seconds < 3600) {
    mins <- max(1L, as.integer(round(seconds / 60)))
    return(sprintf("about %d minute%s", mins, if (mins == 1L) "" else "s"))
  }
  sprintf("about %.1f hours", round(seconds / 3600, 1))
}

#' Default interactive Live Run estimate limit (seconds)
#'
#' Reads \code{options(replicate_shiny.wzb_live_run_max_seconds)} (default 600).
#' On WZB this is a hard gate; elsewhere it is a soft warning threshold.
#'
#' @return Finite positive seconds, or \code{Inf} when disabled.
#' @keywords internal
shiny_live_run_estimate_limit_seconds <- function() {
  raw <- getOption("replicate_shiny.wzb_live_run_max_seconds", 600)
  secs <- suppressWarnings(as.numeric(raw[[1L]] %||% raw))
  if (!is.finite(secs) || secs <= 0) {
    return(Inf)
  }
  secs
}

#' User-facing message when a Live Run estimate exceeds the interactive limit
#'
#' @param estimate_seconds Estimated completion seconds.
#' @param limit_seconds Interactive limit seconds.
#' @param block When \code{TRUE}, copy asks the user to run locally (WZB).
#'   When \code{FALSE}, warns but allows continuing locally.
#' @return Character scalar.
#' @keywords internal
format_live_run_estimate_gate <- function(
  estimate_seconds,
  limit_seconds,
  block = FALSE
) {
  est <- format_run_duration_short(estimate_seconds)
  lim <- format_run_duration_short(limit_seconds)
  if (isTRUE(block)) {
    return(paste0(
      "This step can be run in principle, but the estimated completion time (",
      est,
      ") is above the current WZB Shiny live-run limit (",
      lim,
      "). To preserve shared server resources, please run it locally instead."
    ))
  }
  paste0(
    "Long run warning: estimated completion time (",
    est,
    ") exceeds the usual interactive limit (",
    lim,
    "). The run will continue here; for a complete live result, consider ",
    "running locally via run_replication()."
  )
}

#' Resolve Display chrome for one step (sink + gap + incomplete)
#'
#' @inheritParams load_replication_for_display
#' @return List with \code{displayable}, \code{output_exists}, \code{gap},
#'   \code{incomplete}, \code{entry}, and \code{message}.
#' @keywords internal
shiny_step_display_chrome <- function(
  doi,
  what,
  language = NULL,
  repo = NULL,
  folder = NULL
) {
  meta <- tryCatch(
    get_replication_meta(doi, repo = repo, folder = folder),
    error = function(e) NULL
  )
  entry <- if (!is.null(meta)) {
    tryCatch(
      find_replication_entry(meta, what, language = language),
      error = function(e) NULL
    )
  } else {
    NULL
  }
  incomplete <- isTRUE(entry$incomplete[[1]] %||% entry$incomplete %||% FALSE)
  output_exists <- tryCatch(
    step_display_output_exists(
      doi,
      what,
      repo = repo,
      folder = folder,
      language = language
    ),
    error = function(e) FALSE
  )

  req_eng <- tolower(trimws(as.character(
    entry$requires_engine[[1]] %||% entry$requires_engine %||% ""
  )))
  engine_available <- NULL
  audit_engine_skip <- FALSE
  if (nzchar(req_eng) && !req_eng %in% c("r", "stata", "python")) {
    engine_available <- tryCatch(
      system_engine_available(req_eng),
      error = function(e) NULL
    )
    audit_hit <- tryCatch(
      lookup_replication_audit_engine_skip(
        doi,
        what,
        engine = language %||% audit_replication_engine(entry)
      ),
      error = function(e) NULL
    )
    audit_engine_skip <- isTRUE(audit_hit$skipped_engine)
  }

  gap <- tryCatch(
    classify_shiny_run_gap(
      entry %||% list(id = what),
      output_exists = isTRUE(output_exists),
      audit_skipped_engine = isTRUE(audit_engine_skip),
      engine_available = engine_available
    ),
    error = function(e) list(kind = NULL, message = NULL)
  )

  displayable <- shiny_step_show_display(
    output_exists = isTRUE(output_exists),
    gap_kind = gap$kind,
    incomplete = incomplete
  )

  msg <- ""
  if (!isTRUE(displayable)) {
    msg <- as.character(gap$message %||% "")
    if (!nzchar(msg)) {
      msg <- paste0(
        "Display unavailable: no baked sink for this step",
        if (isTRUE(incomplete) || nzchar(as.character(gap$kind %||% ""))) {
          " (incomplete / engine or data gap)"
        } else {
          ""
        },
        "."
      )
    }
  }

  list(
    displayable = isTRUE(displayable),
    output_exists = isTRUE(output_exists),
    gap = gap,
    incomplete = incomplete,
    entry = entry,
    message = msg
  )
}

#' Shared Shiny Display button action
#'
#' Prefer precomputed artifact (\code{fallback_live = FALSE}), then resolve via
#' [resolve_replication_display()]. When Display would be greyed
#' (\code{!shiny_step_show_display}), short-circuits with a clear
#' missing/unavailable result instead of a full failing artifact load.
#'
#' @inheritParams load_replication_for_display
#' @param short_circuit_unavailable When \code{TRUE} (default), skip artifact
#'   load when Display chrome says the object is unavailable.
#' @return List with \code{ok}, \code{value}/\code{raw}, \code{source}, and
#'   optional \code{error}, \code{missing}, \code{unavailable}, \code{message}.
#' @keywords internal
#' @seealso [shiny_run_action()], [load_replication_for_display()]
shiny_display_action <- function(
  doi,
  what,
  language = NULL,
  repo = NULL,
  folder = NULL,
  short_circuit_unavailable = TRUE
) {
  chrome <- shiny_step_display_chrome(
    doi,
    what,
    language = language,
    repo = repo,
    folder = folder
  )

  if (isTRUE(short_circuit_unavailable) && !isTRUE(chrome$displayable)) {
    return(list(
      ok = FALSE,
      missing = TRUE,
      unavailable = TRUE,
      source = "artifact",
      message = chrome$message,
      chrome = chrome
    ))
  }

  loaded <- load_replication_for_display(
    doi,
    what,
    language = language,
    prefer = "artifact",
    fallback_live = FALSE,
    install_deps = FALSE,
    repo = repo,
    folder = folder
  )

  if (!isTRUE(loaded$ok)) {
    loaded$chrome <- chrome
    if (is.null(loaded$message) || !nzchar(as.character(loaded$message %||% ""))) {
      loaded$message <- if (isTRUE(loaded$missing)) {
        "No precomputed artifact"
      } else if (!is.null(loaded$error)) {
        replication_error_message(loaded$error)
      } else {
        "Display failed"
      }
    }
    return(loaded)
  }

  resolved <- resolve_replication_display(
    doi,
    what,
    loaded$raw %||% loaded$value,
    language = language,
    source = "artifact",
    install_deps = FALSE,
    repo = repo,
    folder = folder
  )

  if (!isTRUE(resolved$ok)) {
    return(list(
      ok = FALSE,
      error = resolved$error %||% simpleError("Display resolve failed"),
      missing = isTRUE(resolved$missing),
      source = "artifact",
      message = if (isTRUE(resolved$missing)) {
        "No precomputed artifact"
      } else {
        replication_error_message(
          resolved$error %||% simpleError("Display resolve failed")
        )
      },
      chrome = chrome
    ))
  }

  list(
    ok = TRUE,
    value = resolved$value,
    raw = loaded$raw %||% loaded$value,
    source = "artifact",
    chrome = chrome
  )
}

#' Shared Shiny Live Run button action
#'
#' Gates (in order): \code{shiny_run: false}, padlock/hammer gap, study
#' compatibility, then long-run estimate. When gates pass and
#' \code{execute = TRUE}, runs leaf-only live display
#' (\code{prefer = "live"}) and resolves via [resolve_replication_display()].
#'
#' **Estimate gate:** when estimated runtime exceeds
#' [shiny_live_run_estimate_limit_seconds()], WZB sessions
#' (\code{on_wzb = TRUE}) hard-block; local/non-WZB sessions get a
#' \code{long_run_warning} but may still run (soft gate).
#'
#' @inheritParams load_replication_for_display
#' @param study_root Optional local study root for audit runtime lookup.
#' @param on_wzb Whether this is a WZB Shiny host (hard estimate block).
#'   Default: [shiny_running_on_wzb()].
#' @param estimate_limit_seconds Interactive estimate limit; default from
#'   [shiny_live_run_estimate_limit_seconds()].
#' @param check_compatibility Run [check_study_compatibility()] before live.
#' @param execute When \code{FALSE}, only evaluate gates / estimate (for Shiny
#'   modals + progress). When \code{TRUE}, also run the live replication.
#' @return List with \code{ok}, \code{ok_to_execute}, \code{gate},
#'   \code{message}, optional live result fields, and estimate metadata.
#' @keywords internal
#' @seealso [shiny_display_action()], [load_replication_for_display()]
shiny_run_action <- function(
  doi,
  what,
  language = NULL,
  repo = NULL,
  folder = NULL,
  install_deps = TRUE,
  study_root = NULL,
  on_wzb = NULL,
  estimate_limit_seconds = NULL,
  check_compatibility = TRUE,
  execute = TRUE
) {
  if (is.null(on_wzb)) {
    on_wzb <- isTRUE(tryCatch(shiny_running_on_wzb(), error = function(e) FALSE))
  } else {
    on_wzb <- isTRUE(on_wzb)
  }
  if (is.null(estimate_limit_seconds)) {
    estimate_limit_seconds <- shiny_live_run_estimate_limit_seconds()
  } else {
    estimate_limit_seconds <- suppressWarnings(
      as.numeric(estimate_limit_seconds[[1L]] %||% estimate_limit_seconds)
    )
    if (!is.finite(estimate_limit_seconds) || estimate_limit_seconds <= 0) {
      estimate_limit_seconds <- Inf
    }
  }

  empty_ok <- function(...) {
    dots <- list(...)
    base <- list(
      ok = FALSE,
      ok_to_execute = FALSE,
      source = "live",
      gate = NULL,
      message = "",
      skipped = FALSE,
      estimate_blocked = FALSE,
      estimate_seconds = NA_real_,
      limit_seconds = estimate_limit_seconds,
      long_run_warning = "",
      progress_message = "Running live replication...",
      compatibility = NULL
    )
    modifyList(base, dots)
  }

  meta <- tryCatch(
    get_replication_meta(doi, repo = repo, folder = folder),
    error = function(e) e
  )
  if (inherits(meta, "error")) {
    return(empty_ok(
      gate = "meta",
      error = meta,
      message = conditionMessage(meta)
    ))
  }

  entry <- tryCatch(
    find_replication_entry(meta, what, language = language),
    error = function(e) NULL
  )

  if (!isTRUE(step_shiny_run_enabled(entry))) {
    msg <- step_shiny_run_message(entry)
    return(empty_ok(
      gate = "shiny_run",
      skipped = TRUE,
      message = msg,
      error = simpleError(msg)
    ))
  }

  chrome <- shiny_step_display_chrome(
    doi,
    what,
    language = language,
    repo = repo,
    folder = folder
  )
  gap <- chrome$gap %||% list(kind = NULL)
  if (identical(gap$kind, "padlock") || identical(gap$kind, "hammer")) {
    msg <- as.character(gap$message %||% "Live Run unavailable for this step.")
    return(empty_ok(
      gate = "gap",
      skipped = TRUE,
      message = msg,
      error = simpleError(msg),
      chrome = chrome
    ))
  }
  incomplete <- isTRUE(chrome$incomplete)
  if (isTRUE(incomplete)) {
    msg <- as.character(
      entry$blocked_reason[[1]] %||% entry$blocked_reason %||%
        "This step is marked incomplete and cannot be run live."
    )
    return(empty_ok(
      gate = "incomplete",
      skipped = TRUE,
      message = msg,
      error = simpleError(msg),
      chrome = chrome
    ))
  }

  compatibility <- NULL
  if (isTRUE(check_compatibility)) {
    compatibility <- tryCatch(
      check_study_compatibility(
        doi,
        folder = folder,
        repo = repo,
        materialize_study = TRUE,
        include_registry_audit = FALSE
      ),
      error = function(e) {
        list(
          error = conditionMessage(e),
          message = conditionMessage(e),
          ready = FALSE
        )
      }
    )
    if (!is.null(compatibility$error) || !isTRUE(compatibility$ready)) {
      hint <- as.character(
        compatibility$message %||%
          compatibility$error %||%
          "Study compatibility check failed (not ready)"
      )
      return(empty_ok(
        gate = "compat",
        message = hint,
        compatibility = compatibility,
        error = structure(
          list(message = hint),
          class = c("dependency_error", "error", "condition")
        )
      ))
    }
  }

  rt <- tryCatch(
    lookup_replication_audit_runtime(
      doi,
      what,
      engine = language,
      study_root = study_root
    ),
    error = function(e) NULL
  )
  estimate_seconds <- shiny_runtime_estimate_seconds(rt)
  progress_message <- "Running live replication..."
  long_run_warning <- ""

  if (!is.null(rt) && isTRUE(rt$timed_out)) {
    long_ind <- shiny_step_long_run_indicator(
      output_exists = isTRUE(chrome$output_exists),
      audit_timed_out = TRUE,
      gap_kind = NULL,
      incomplete = FALSE,
      timeout_seconds = rt$timeout_seconds %||% NA_real_,
      seconds = rt$seconds %||% NA_real_,
      bake_seconds = rt$bake_seconds %||% NA_real_
    )
    if (isTRUE(long_ind$show) && nzchar(long_ind$title %||% "")) {
      progress_message <- paste0(
        "Running live replication... ",
        long_ind$title
      )
      long_run_warning <- long_ind$title
    } else if (nzchar(rt$advice %||% "")) {
      progress_message <- paste0("Running live replication... ", rt$advice)
      long_run_warning <- rt$advice
    }
  } else if (!is.null(rt) && isTRUE(rt$available) && nzchar(rt$advice %||% "")) {
    progress_message <- paste0("Running live replication... ", rt$advice)
  }

  if (
    is.finite(estimate_limit_seconds) &&
      is.finite(estimate_seconds) &&
      estimate_seconds > estimate_limit_seconds
  ) {
    if (isTRUE(on_wzb)) {
      polite <- format_live_run_estimate_gate(
        estimate_seconds,
        estimate_limit_seconds,
        block = TRUE
      )
      return(empty_ok(
        gate = "estimate",
        estimate_blocked = TRUE,
        estimate_seconds = estimate_seconds,
        message = polite,
        long_run_warning = polite,
        progress_message = progress_message,
        compatibility = compatibility,
        chrome = chrome,
        runtime = rt
      ))
    }
    long_run_warning <- format_live_run_estimate_gate(
      estimate_seconds,
      estimate_limit_seconds,
      block = FALSE
    )
    progress_message <- paste0(
      "Running live replication... ",
      long_run_warning
    )
  }

  preflight <- list(
    ok = FALSE,
    ok_to_execute = TRUE,
    source = "live",
    gate = NULL,
    message = "",
    skipped = FALSE,
    estimate_blocked = FALSE,
    estimate_seconds = estimate_seconds,
    limit_seconds = estimate_limit_seconds,
    long_run_warning = long_run_warning,
    progress_message = progress_message,
    compatibility = compatibility,
    chrome = chrome,
    runtime = rt
  )

  if (!isTRUE(execute)) {
    return(preflight)
  }

  loaded <- load_replication_for_display(
    doi,
    what,
    language = language,
    prefer = "live",
    fallback_live = FALSE,
    install_deps = install_deps,
    repo = repo,
    folder = folder
  )

  if (!isTRUE(loaded$ok)) {
    return(modifyList(preflight, list(
      ok = FALSE,
      error = loaded$error,
      missing = isTRUE(loaded$missing),
      message = if (!is.null(loaded$error)) {
        replication_error_message(loaded$error)
      } else if (isTRUE(loaded$missing)) {
        "Live Run returned no display value"
      } else {
        "Live Run failed"
      }
    )))
  }

  resolved <- resolve_replication_display(
    doi,
    what,
    loaded$raw %||% loaded$value,
    language = language,
    source = "live",
    install_deps = isTRUE(install_deps),
    repo = repo,
    folder = folder
  )

  if (!isTRUE(resolved$ok)) {
    return(modifyList(preflight, list(
      ok = FALSE,
      error = resolved$error %||% simpleError("Live display resolve failed"),
      missing = isTRUE(resolved$missing),
      message = if (isTRUE(resolved$missing)) {
        "Live Run returned no display value"
      } else {
        replication_error_message(
          resolved$error %||% simpleError("Live display resolve failed")
        )
      }
    )))
  }

  modifyList(preflight, list(
    ok = TRUE,
    value = resolved$value,
    raw = loaded$raw %||% loaded$value,
    message = ""
  ))
}

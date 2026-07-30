#' Whether Shiny Live Run is allowed for a step
#'
#' Reads yaml \code{shiny_run:} (default \code{TRUE}). When \code{false}, the
#' Shiny app greys out / disables Live Run for that step only. Display of baked
#' sinks, the Code tab, and package APIs (\code{run_replication()}, bake,
#' audit) are unchanged. Do \strong{not} use \code{incomplete: true} for this
#' purpose — that also skips package Run / audit.
#'
#' @param entry Step list (yaml entry or Shiny row fields as a list).
#' @return Logical; \code{TRUE} when Live Run should be offered.
#' @keywords internal
step_shiny_run_enabled <- function(entry) {
  if (is.null(entry) || !is.list(entry)) {
    return(TRUE)
  }
  raw <- entry$shiny_run[[1]] %||% entry$shiny_run %||% NULL
  if (is.null(raw)) {
    return(TRUE)
  }
  if (is.logical(raw)) {
    return(isTRUE(raw))
  }
  tok <- tolower(trimws(as.character(raw)))
  if (!nzchar(tok) || tok %in% c("true", "yes", "1", "on")) {
    return(TRUE)
  }
  if (tok %in% c("false", "no", "0", "off")) {
    return(FALSE)
  }
  TRUE
}

#' User-facing reason when Shiny Live Run is disabled for a step
#'
#' Fixed short label shown on the greyed Shiny **Run** control (tooltip /
#' gate message) when \code{shiny_run: false}. Display / Code / package Run
#' are unchanged. Yaml \code{blocked_reason:} is not used here (that field
#' remains for \code{incomplete:} / engine / data gaps).
#'
#' @param entry Step list (yaml entry or Shiny row fields as a list).
#'   Ignored; accepted so call sites can pass the step entry uniformly.
#' @return Character scalar: \code{"[live run not available on shiny]"}.
#' @keywords internal
step_shiny_run_message <- function(entry) {
  "[live run not available on shiny]"
}

#' Whether a Shiny step has a Display-available object
#'
#' Used for Display chrome (not for omitting the control): when this returns
#' \code{FALSE}, Shiny still shows Display but greys it (still clickable so
#' users can open Code / see the short unavailable note). When \code{TRUE},
#' Display uses the same filled dark style as enabled Run.
#'
#' Correct enablement (do \strong{not} invert):
#' \itemize{
#'   \item Baked sink present (\code{output_exists}): available, including
#'     engine/data gaps that still have a precomputed artifact.
#'   \item Engine/data gap or generic incomplete \emph{without} a sink: not
#'     available (padlock / wrench; grey Display).
#'   \item Normal runnable step without a detected sink: still available
#'     (prep preview / live path may work).
#' }
#'
#' The historical bug was \code{displayable = output_exists || is_gap}, which
#' greyd available prep rows without html/png sinks while leaving Mathematica
#' / data-gap rows clickable.
#'
#' @param output_exists Whether a declared display artifact is already available.
#' @param gap_kind From [classify_shiny_run_gap()] (\code{"padlock"},
#'   \code{"hammer"}, or \code{NULL}).
#' @param incomplete Whether the step is marked incomplete.
#' @return Logical.
#' @keywords internal
shiny_step_show_display <- function(
  output_exists = FALSE,
  gap_kind = NULL,
  incomplete = FALSE
) {
  if (isTRUE(output_exists)) {
    return(TRUE)
  }
  kind <- tolower(trimws(as.character(gap_kind[[1L]] %||% "")))
  if (nzchar(kind)) {
    return(FALSE)
  }
  if (isTRUE(incomplete)) {
    return(FALSE)
  }
  TRUE
}

#' Format a user-facing warning for audit-timeout / long Runs
#'
#' @param timeout_seconds Audit patience / cap in seconds when known.
#' @param seconds Elapsed seconds from the audit row (often equals the cap).
#' @return Character scalar.
#' @keywords internal
format_long_run_warning <- function(
  timeout_seconds = NA_real_,
  seconds = NA_real_,
  bake_seconds = NA_real_
) {
  fmt_dur <- function(cap) {
    if (!is.finite(cap) || cap <= 0) {
      return(NULL)
    }
    if (cap < 60) {
      sprintf("%.0f seconds", cap)
    } else if (cap < 3600) {
      mins <- max(1L, as.integer(round(cap / 60)))
      sprintf("about %d minute%s", mins, if (mins == 1L) "" else "s")
    } else {
      sprintf("about %.1f hours", cap / 3600)
    }
  }

  bake <- as.numeric(bake_seconds[[1L]] %||% NA_real_)
  bake_txt <- fmt_dur(bake)

  cap <- as.numeric(timeout_seconds[[1L]] %||% NA_real_)
  if (!is.finite(cap) || cap <= 0) {
    cap <- as.numeric(seconds[[1L]] %||% NA_real_)
  }
  # Prefer last successful bake duration when audit only hit the patience cap.
  if (is.finite(bake) && bake > 0 &&
      (!is.finite(cap) || cap <= 0 ||
         (is.finite(seconds) && is.finite(cap) &&
            abs(as.numeric(seconds) - cap) < 1))) {
    source_bit <- paste0("last successful bake took ", bake_txt)
  } else {
    cap_txt <- fmt_dur(cap) %||% "the configured audit time limit"
    source_bit <- paste0(
      "registry audit for this step hit the time cap (",
      cap_txt,
      ")"
    )
    if (!is.null(bake_txt)) {
      source_bit <- paste0(
        source_bit,
        "; last successful bake took ",
        bake_txt
      )
    }
  }

  paste0(
    "Long run warning: ",
    source_bit,
    ". A live Run may not complete during a typical browser session. ",
    "For a complete live result, consider running locally."
  )
}

#' Decide whether to show a long/slow Run indicator (hourglass) beside Run
#'
#' Show when \strong{all} of:
#' \enumerate{
#'   \item A Display sink / baked artifact exists
#'   \item Registry audit marked the step as timed out
#'   \item The step is otherwise runnable (no padlock / wrench gap; not incomplete)
#' }
#' Generic across studies — any step matching these signals qualifies.
#'
#' @param output_exists Whether a display artifact exists.
#' @param audit_timed_out Whether the matching audit row timed out.
#' @param gap_kind From [classify_shiny_run_gap()] (\code{NULL} when runnable).
#' @param incomplete Whether the step is marked incomplete.
#' @param timeout_seconds Optional audit cap seconds for the warning text.
#' @param seconds Optional elapsed seconds from the audit row.
#' @param bake_seconds Optional last successful bake seconds from
#'   [lookup_study_replication_timing()].
#' @return List with \code{show}, \code{title}, \code{message},
#'   \code{timeout_seconds}, \code{seconds}, and \code{bake_seconds}.
#' @keywords internal
shiny_step_long_run_indicator <- function(
  output_exists = FALSE,
  audit_timed_out = FALSE,
  gap_kind = NULL,
  incomplete = FALSE,
  timeout_seconds = NA_real_,
  seconds = NA_real_,
  bake_seconds = NA_real_
) {
  kind <- tolower(trimws(as.character(gap_kind[[1L]] %||% "")))
  has_gap <- nzchar(kind)
  show <- isTRUE(output_exists) &&
    isTRUE(audit_timed_out) &&
    !has_gap &&
    !isTRUE(incomplete)

  warning <- if (isTRUE(show)) {
    format_long_run_warning(
      timeout_seconds = timeout_seconds,
      seconds = seconds,
      bake_seconds = bake_seconds
    )
  } else {
    ""
  }

  list(
    show = show,
    title = warning,
    message = warning,
    timeout_seconds = as.numeric(timeout_seconds[[1L]] %||% NA_real_),
    seconds = as.numeric(seconds[[1L]] %||% NA_real_),
    bake_seconds = as.numeric(bake_seconds[[1L]] %||% NA_real_)
  )
}

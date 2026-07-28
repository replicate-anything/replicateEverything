#' Whether Shiny should show a Display control for a step
#'
#' Correct enablement (do \strong{not} invert):
#' \itemize{
#'   \item Baked sink present (\code{output_exists}): always show Display,
#'     including engine/data gaps that still have a precomputed artifact.
#'   \item Engine/data gap or generic incomplete \emph{without} a sink: omit
#'     Display entirely (padlock / wrench open Code). Never treat gap kind as
#'     a reason to show an active Display affordance.
#'   \item Normal runnable step without a detected sink: still show Display
#'     (prep preview / live path may work; avoids greying available steps).
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

#' Format a lengthy user-facing warning for audit-timeout / long Runs
#'
#' @param timeout_seconds Audit patience / cap in seconds when known.
#' @param seconds Elapsed seconds from the audit row (often equals the cap).
#' @return Character scalar.
#' @keywords internal
format_long_run_warning <- function(
  timeout_seconds = NA_real_,
  seconds = NA_real_
) {
  cap <- as.numeric(timeout_seconds[[1L]] %||% NA_real_)
  if (!is.finite(cap) || cap <= 0) {
    cap <- as.numeric(seconds[[1L]] %||% NA_real_)
  }
  cap_txt <- if (is.finite(cap) && cap > 0) {
    if (cap < 60) {
      sprintf("%.0f seconds", cap)
    } else if (cap < 3600) {
      mins <- max(1L, as.integer(round(cap / 60)))
      sprintf("about %d minute%s", mins, if (mins == 1L) "" else "s")
    } else {
      sprintf("about %.1f hours", cap / 3600)
    }
  } else {
    "the configured audit time limit"
  }
  paste0(
    "Long run warning: registry audit for this step hit the time cap (",
    cap_txt,
    "). A live Run can take a long time — often as long as the audit allowed, ",
    "and sometimes longer — and may not finish during a typical browser session. ",
    "Display shows a precomputed result when one is available. ",
    "If you start Run, leave this tab open and expect a substantial wait. ",
    "For a complete live result, consider running locally with a higher ",
    "audit patience setting."
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
#' @return List with \code{show}, \code{title}, \code{message},
#'   \code{timeout_seconds}, and \code{seconds}.
#' @keywords internal
shiny_step_long_run_indicator <- function(
  output_exists = FALSE,
  audit_timed_out = FALSE,
  gap_kind = NULL,
  incomplete = FALSE,
  timeout_seconds = NA_real_,
  seconds = NA_real_
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
      seconds = seconds
    )
  } else {
    ""
  }

  list(
    show = show,
    title = warning,
    message = warning,
    timeout_seconds = as.numeric(timeout_seconds[[1L]] %||% NA_real_),
    seconds = as.numeric(seconds[[1L]] %||% NA_real_)
  )
}

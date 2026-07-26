#' Run a single replication or all replications for a paper
#'
#' Executes a specific replication (figure or table) for a paper, or every step
#' in the study DAG when `what = "everything"` (transform, table, and figure
#' steps; format children run only when `format = TRUE`).
#'
#' By default returns the raw analysis object (e.g. a \code{glm} or \code{ggplot}).
#' Set \code{format = TRUE} or \code{format = "if_available"} to apply the
#' registered \code{format_*} step when \code{replication.yml} defines one
#' (same step used for display outputs and Shiny).
#'
#' @param doi Character. DOI, registry handle, or local study path (see
#'   [resolve_doi_input()]). Pass \code{"local"} to run against the study in
#'   the current working directory — no registry lookup is needed.
#' @param what Character. Step or replication identifier (e.g. \code{"tab_1"}),
#'   or \code{"everything"} to run all non-format steps in the study DAG.
#' @param language Optional \code{"R"}, \code{"stata"}, or \code{"python"}. When
#'   omitted and the replication has only one engine, that engine is used
#'   automatically. When both R and Stata exist for the same logical id, R is
#'   preferred unless \code{language} is set.
#' @param given Assumed-complete steps. For a single step, defaults to
#'   \code{"parents"} (immediate parent outputs must exist). For
#'   \code{what = "everything"}, defaults to \code{"nothing"} (run the full
#'   upstream DAG). May also be a character vector of step ids.
#' @param force Logical. Re-run steps even when declared \code{outputs/} already
#'   exist. Defaults to \code{TRUE}: [run_replication()] is a live Run (unlike
#'   Display / [load_artifact()], which use precomputed files). Set
#'   \code{force = FALSE} to reuse existing upstream outputs when present; the
#'   target step still recomputes.
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#' @param format Logical or \code{"if_available"}. Apply display formatting when
#'   available. When \code{what = "everything"}, applies to each step in the
#'   returned list (\code{FALSE} returns raw analysis objects only).
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return For a single replication, the analysis or formatted object. For
#'   \code{what = "everything"}, a named list of results for every non-format
#'   step in the study DAG (invisibly).
#'
#' @examples
#' \dontrun{
#' run_replication("10.1177/00491241211036161", "fig_1", format = TRUE)
#' run_replication("bounding-causes", "fig_1")
#' run_replication("10.1017/S0003055403000534", "tab_1", format = TRUE)
#' run_replication("10.1017/S0003055403000534", "tab_1", language = "stata")
#' run_replication("10.1177/00491241211036161", "everything")
#'
#' # setwd() to a checked-out study repo (or open its RStudio project) and
#' # run a step against it directly — no DOI or registry lookup required.
#' setwd("path/to/rep-my-study")
#' run_replication("local", "tab_1")
#' run_replication("local", "fig_1", format = TRUE)
#' }
#'
#' @export
run_replication <- function(
  doi,
  what,
  language = NULL,
  given = NULL,
  force = TRUE,
  install_deps = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
) {
  if (is.null(given)) {
    given <- if (identical(what, "everything")) "nothing" else "parents"
  }
  if (identical(what, "everything")) {
    return(run_all_replications(
      doi,
      language = language,
      given = given,
      force = force,
      install_deps = install_deps,
      format = format,
      repo = repo,
      folder = folder
    ))
  }

  run_replication_one(
    doi,
    what,
    language = language,
    given = given,
    force = force,
    install_deps = install_deps,
    format = format,
    repo = repo,
    folder = folder
  )
}

#' Human-readable reason a step is unavailable, or NULL when it is runnable
#'
#' Reads the \code{incomplete:} / \code{blocked_reason:} fields declared on a
#' step in \code{replication.yml}. \code{incomplete: true} with no
#' \code{blocked_reason} still blocks the step, using a generic message.
#' @keywords internal
step_blocked_reason <- function(meta, what) {
  entry <- tryCatch(find_replication_entry(meta, what), error = function(e) NULL)
  if (is.null(entry) || !isTRUE(entry$incomplete %||% FALSE)) {
    return(NULL)
  }
  reason <- as.character(entry$blocked_reason %||% "")
  if (!nzchar(reason)) {
    reason <- "marked incomplete in replication.yml (no reason given)"
  }
  reason
}

#' Map a yaml engine token to a display name (e.g. mathematica -> Mathematica)
#' @keywords internal
normalize_engine_display_name <- function(token) {
  tok <- tolower(trimws(as.character(token[[1]] %||% token)))
  if (!nzchar(tok)) {
    return(NULL)
  }
  known <- c(
    mathematica = "Mathematica",
    wolfram = "Mathematica",
    wolframscript = "Mathematica",
    matlab = "MATLAB",
    stata = "Stata",
    python = "Python",
    r = "R",
    julia = "Julia"
  )
  if (tok %in% names(known)) {
    return(unname(known[[tok]]))
  }
  # Title-case unknown tokens
  paste0(toupper(substr(tok, 1L, 1L)), substr(tok, 2L, nchar(tok)))
}

#' Required proprietary/system engine for a blocked step, if declared or inferred
#'
#' Prefers structured yaml \code{requires_engine:} (or \code{system_requirements:}),
#' then parses common names out of \code{blocked_reason:}.
#' @keywords internal
step_required_engine <- function(entry) {
  if (is.null(entry) || !is.list(entry)) {
    return(NULL)
  }
  for (field in c("requires_engine", "required_engine")) {
    val <- entry[[field]] %||% NULL
    if (!is.null(val) && length(val) > 0L) {
      name <- normalize_engine_display_name(val[[1]])
      if (!is.null(name)) {
        return(name)
      }
    }
  }
  sys <- entry$system_requirements %||% entry$system_requirement %||% NULL
  if (!is.null(sys) && length(sys) > 0L) {
    for (item in sys) {
      name <- normalize_engine_display_name(item)
      if (!is.null(name) && !name %in% c("R", "Stata", "Python")) {
        return(name)
      }
    }
    name <- normalize_engine_display_name(sys[[1]])
    if (!is.null(name)) {
      return(name)
    }
  }
  reason <- as.character(entry$blocked_reason %||% "")
  if (!nzchar(reason)) {
    return(NULL)
  }
  patterns <- c(
    Mathematica = "(?i)\\b(mathematica|wolframscript|wolfram)\\b",
    MATLAB = "(?i)\\bmatlab\\b",
    Julia = "(?i)\\bjulia\\b"
  )
  for (nm in names(patterns)) {
    if (grepl(patterns[[nm]], reason, perl = TRUE)) {
      return(nm)
    }
  }
  NULL
}

#' Message when an output cannot be shown or re-run due to a missing engine
#'
#' Two modes (exact phrasing):
#' \itemize{
#'   \item \code{not_available}: \code{"{output} not available because of missing {Engine} engine"}
#'   \item \code{not_reproducible}: \code{"{output} not reproducible because of missing {Engine} engine"}
#' }
#' @keywords internal
missing_engine_message <- function(output, engine, mode = c("not_available", "not_reproducible")) {
  mode <- match.arg(mode)
  output <- trimws(as.character(output[[1]] %||% output))
  engine <- trimws(as.character(engine[[1]] %||% engine))
  if (!nzchar(output)) {
    output <- "Output"
  }
  if (!nzchar(engine)) {
    engine <- "required"
  }
  if (identical(mode, "not_available")) {
    paste0(output, " not available because of missing ", engine, " engine")
  } else {
    paste0(output, " not reproducible because of missing ", engine, " engine")
  }
}

#' Structured data-unavailability class from yaml (e.g. proprietary)
#'
#' Reads \code{data_unavailable:} (or legacy \code{unavailable_reason:} /
#' \code{requires_data:}) on an incomplete step. Tokens are lower-case
#' (\code{proprietary}, \code{restricted}, \code{missing}, \ldots).
#' @keywords internal
step_data_unavailable <- function(entry) {
  if (is.null(entry) || !is.list(entry)) {
    return(NULL)
  }
  if (!isTRUE(entry$incomplete %||% FALSE)) {
    return(NULL)
  }
  for (field in c("data_unavailable", "unavailable_reason", "requires_data")) {
    val <- entry[[field]] %||% NULL
    if (is.null(val) || !length(val)) {
      next
    }
    tok <- tolower(trimws(as.character(val[[1]] %||% val)))
    if (nzchar(tok) && !tok %in% c("false", "no", "0", "na", "null", "none")) {
      return(tok)
    }
  }
  NULL
}

#' Human label for a data_unavailable token
#' @keywords internal
normalize_data_unavailable_label <- function(token) {
  tok <- tolower(trimws(as.character(token[[1]] %||% token)))
  if (!nzchar(tok)) {
    return(NULL)
  }
  known <- c(
    proprietary = "proprietary data",
    restricted = "restricted data",
    confidential = "confidential data",
    missing = "missing data",
    unavailable = "unavailable data"
  )
  if (tok %in% names(known)) {
    return(unname(known[[tok]]))
  }
  paste(tok, "data")
}

#' Message when an output cannot be shown or re-run due to unavailable data
#' @keywords internal
missing_data_message <- function(output, data_class, mode = c("not_available", "not_reproducible")) {
  mode <- match.arg(mode)
  output <- trimws(as.character(output[[1]] %||% output))
  data_class <- trimws(as.character(data_class[[1]] %||% data_class))
  if (!nzchar(output)) {
    output <- "Output"
  }
  if (!nzchar(data_class)) {
    data_class <- "unavailable data"
  }
  label <- normalize_data_unavailable_label(data_class) %||% data_class
  if (identical(mode, "not_available")) {
    paste0(output, " not available because of ", label)
  } else {
    paste0(output, " not reproducible because of ", label)
  }
}

#' Collect data_unavailable tokens from incomplete steps
#' @keywords internal
study_data_unavailable_classes <- function(meta) {
  entries <- if (is.list(meta) && !is.null(meta$steps)) {
    tryCatch(collect_study_step_entries(meta), error = function(e) list())
  } else if (is.list(meta) && length(meta) > 0L && is.list(meta[[1]])) {
    meta
  } else {
    list()
  }
  classes <- character(0)
  for (entry in entries) {
    tok <- step_data_unavailable(entry)
    if (!is.null(tok)) {
      classes <- c(classes, tok)
    }
  }
  unique(classes)
}

#' User-facing blocked-step message, distinguishing absent vs baked-but-blocked
#'
#' Prefers \code{requires_engine:} phrasing, then \code{data_unavailable:}, then
#' free-text \code{blocked_reason:}.
#'
#' @param output_exists Whether a declared display artifact is already on disk
#'   (or otherwise fetchable). When \code{TRUE}, the step is "not reproducible";
#'   when \code{FALSE}, it is "not available".
#' @keywords internal
step_missing_engine_message <- function(meta, what, output_exists = FALSE) {
  entry <- tryCatch(find_replication_entry(meta, what), error = function(e) NULL)
  if (is.null(entry) || !isTRUE(entry$incomplete %||% FALSE)) {
    return(NULL)
  }
  engine <- step_required_engine(entry)
  label <- as.character(entry$label %||% what)
  if (!nzchar(label)) {
    label <- as.character(what)
  }
  mode <- if (isTRUE(output_exists)) "not_reproducible" else "not_available"
  if (!is.null(engine)) {
    return(missing_engine_message(label, engine, mode = mode))
  }
  data_tok <- step_data_unavailable(entry)
  if (!is.null(data_tok)) {
    return(missing_data_message(label, data_tok, mode = mode))
  }
  reason <- as.character(entry$blocked_reason %||% "")
  if (!nzchar(reason)) {
    reason <- "marked incomplete in replication.yml (no reason given)"
  }
  if (isTRUE(output_exists)) {
    paste0(label, " not reproducible because of: ", reason)
  } else {
    paste0(label, " not available because of: ", reason)
  }
}

#' System engines required by incomplete / blocked steps (e.g. Mathematica)
#'
#' Scans \code{requires_engine:} / \code{system_requirements:} / blocked-reason
#' text on steps marked \code{incomplete: true}. Does not include ordinary
#' replication engines (R / Stata / Python).
#'
#' @param meta Parsed replication metadata, or a list of step entries.
#' @return Character vector of display names (e.g. \code{"Mathematica"}).
#' @keywords internal
study_required_system_engines <- function(meta) {
  entries <- if (is.list(meta) && !is.null(meta$steps)) {
    tryCatch(collect_study_step_entries(meta), error = function(e) list())
  } else if (is.list(meta) && length(meta) > 0L && is.list(meta[[1]])) {
    meta
  } else {
    list()
  }
  engines <- character(0)
  for (entry in entries) {
    if (!isTRUE(entry$incomplete %||% FALSE)) {
      next
    }
    eng <- step_required_engine(entry)
    if (!is.null(eng) && !eng %in% c("R", "Stata", "Python")) {
      engines <- c(engines, eng)
    }
  }
  unique(engines)
}

#' English list join for short UI phrases
#' @keywords internal
oxford_join <- function(items, conj = "and") {
  items <- as.character(items)
  items <- items[nzchar(items)]
  n <- length(items)
  if (n == 0L) {
    return("")
  }
  if (n == 1L) {
    return(items[[1]])
  }
  if (n == 2L) {
    return(paste(items[[1]], conj, items[[2]]))
  }
  paste0(
    paste(items[-n], collapse = ", "),
    ", ",
    conj,
    " ",
    items[[n]]
  )
}

#' Build the one-line partial-replication notice shown on study select
#' @keywords internal
format_partial_replication_message <- function(
  engines = character(0),
  incomplete_n = 0L,
  audit_failed = 0L,
  audit_timed_out = 0L,
  data_unavailable = character(0)
) {
  engines <- unique(as.character(engines))
  engines <- engines[nzchar(engines)]
  data_unavailable <- unique(tolower(as.character(data_unavailable)))
  data_unavailable <- data_unavailable[nzchar(data_unavailable)]
  incomplete_n <- as.integer(incomplete_n %||% 0L)
  audit_failed <- as.integer(audit_failed %||% 0L)
  audit_timed_out <- as.integer(audit_timed_out %||% 0L)

  bits <- character(0)
  if (length(engines) > 0L) {
    bits <- c(
      bits,
      paste0(
        "missing ",
        oxford_join(engines),
        if (length(engines) == 1L) " installation" else " installations"
      )
    )
  }
  if (length(data_unavailable) > 0L) {
    labels <- vapply(data_unavailable, function(tok) {
      normalize_data_unavailable_label(tok) %||% tok
    }, character(1))
    bits <- c(
      bits,
      paste0("some outputs unavailable due to ", oxford_join(unique(labels)))
    )
  } else if (length(engines) == 0L && incomplete_n > 0L) {
    bits <- c(
      bits,
      sprintf(
        "%d output%s marked incomplete",
        incomplete_n,
        if (incomplete_n == 1L) "" else "s"
      )
    )
  }
  if (audit_timed_out > 0L) {
    bits <- c(bits, "some audit runs timed out")
  } else if (
    audit_failed > 0L &&
      length(engines) == 0L &&
      length(data_unavailable) == 0L &&
      incomplete_n == 0L
  ) {
    bits <- c(bits, "some audit runs failed or are incomplete")
  }

  if (!length(bits)) {
    return(NULL)
  }
  paste0(
    "Only partial replication currently available (",
    paste(bits, collapse = "; "),
    ")"
  )
}

#' Whether an audit skip / error snippet is a missing-engine reason
#'
#' @param reason Character snippet from audit \code{error_snippet} or skip reason.
#' @return \code{TRUE} when the text matches missing-engine phrasing.
#' @keywords internal
audit_reason_is_missing_engine <- function(reason) {
  txt <- as.character(reason[[1]] %||% reason %||% "")
  if (!nzchar(txt)) {
    return(FALSE)
  }
  grepl(
    "missing[[:space:]].+[[:space:]]engine|because of missing[[:space:]]",
    txt,
    ignore.case = TRUE,
    perl = TRUE
  )
}

#' Classify Shiny Run-slot chrome: padlock (data) vs hammer (engine)
#'
#' Layered signals (first match wins for padlock):
#' \enumerate{
#'   \item \strong{Padlock:} yaml \code{data_unavailable:} (Shiny does not need audit).
#'   \item \strong{Hammer (bake gap):} registry audit Skipped + missing-engine reason
#'     when provided; else \code{requires_engine:} with missing display outputs
#'     and/or \code{incomplete: true}.
#'   \item \strong{Hammer (can't re-run):} outputs exist but live engine probe is
#'     false (\code{engine_available = FALSE}).
#' }
#'
#' @param entry Step list (yaml entry or Shiny row fields as a list).
#' @param output_exists Whether a display artifact exists.
#' @param audit_skipped_engine \code{TRUE} when registry audit marks this step
#'   Skipped for a missing-engine reason.
#' @param engine_available Live probe for the required system engine; \code{NULL}
#'   means unknown (do not treat as missing).
#' @return List with \code{kind} (\code{"padlock"}, \code{"hammer"}, or \code{NULL}),
#'   \code{mode}, \code{message}, \code{data_token}, \code{engine}.
#' @keywords internal
classify_shiny_run_gap <- function(
  entry,
  output_exists = FALSE,
  audit_skipped_engine = FALSE,
  engine_available = NULL
) {
  empty <- list(
    kind = NULL,
    mode = NA_character_,
    message = NULL,
    data_token = NULL,
    engine = NULL
  )
  if (is.null(entry) || !is.list(entry)) {
    return(empty)
  }

  label <- as.character(
    entry$label[[1]] %||% entry$label %||%
      entry$description[[1]] %||% entry$description %||%
      entry$id[[1]] %||% entry$id %||% "Output"
  )
  if (!nzchar(label)) {
    label <- "Output"
  }
  mode <- if (isTRUE(output_exists)) "not_reproducible" else "not_available"
  incomplete <- isTRUE(entry$incomplete[[1]] %||% entry$incomplete %||% FALSE)

  data_tok <- step_data_unavailable(entry)
  if (is.null(data_tok)) {
    # Shiny may pass the token without going through incomplete: gating
    raw <- tolower(trimws(as.character(
      entry$data_unavailable[[1]] %||% entry$data_unavailable %||% ""
    )))
    if (nzchar(raw) && !raw %in% c("false", "no", "0", "na", "null", "none")) {
      data_tok <- raw
    }
  }
  if (!is.null(data_tok) && nzchar(data_tok)) {
    return(list(
      kind = "padlock",
      mode = mode,
      message = missing_data_message(label, data_tok, mode = mode),
      data_token = data_tok,
      engine = NULL
    ))
  }

  eng <- step_required_engine(entry)
  if (is.null(eng)) {
    raw_eng <- tolower(trimws(as.character(
      entry$requires_engine[[1]] %||% entry$requires_engine %||% ""
    )))
    if (nzchar(raw_eng)) {
      eng <- normalize_engine_display_name(raw_eng)
    }
  }
  has_system_engine <- !is.null(eng) && !eng %in% c("R", "Stata", "Python")
  engine_missing_live <- isFALSE(engine_available)

  # Hammer: audit bake-gap skip; yaml incomplete + requires_engine; or live
  # probe says the system engine is missing (Display may still work).
  show_hammer <- (isTRUE(audit_skipped_engine) && !isTRUE(output_exists)) ||
    (has_system_engine && incomplete) ||
    (has_system_engine && engine_missing_live)

  if (!isTRUE(show_hammer)) {
    return(empty)
  }

  if (is.null(eng) || !nzchar(as.character(eng))) {
    eng <- "required"
  }
  list(
    kind = "hammer",
    mode = mode,
    message = missing_engine_message(label, eng, mode = mode),
    data_token = NULL,
    engine = eng
  )
}

#' Study-level padlock / hammer flags from step entries
#'
#' @param entries List of step entries (or parsed meta with \code{steps}).
#' @return List with logical \code{data_unavailable} and \code{missing_engine}.
#' @keywords internal
study_gap_flags_from_entries <- function(entries) {
  flags <- list(data_unavailable = FALSE, missing_engine = FALSE)
  if (is.null(entries)) {
    return(flags)
  }
  if (is.list(entries) && !is.null(entries$steps)) {
    entries <- tryCatch(collect_study_step_entries(entries), error = function(e) list())
  }
  if (!is.list(entries) || !length(entries)) {
    return(flags)
  }
  for (entry in entries) {
    if (!is.list(entry)) {
      next
    }
    gap <- classify_shiny_run_gap(entry, output_exists = FALSE)
    if (identical(gap$kind, "padlock")) {
      flags$data_unavailable <- TRUE
    } else if (identical(gap$kind, "hammer")) {
      flags$missing_engine <- TRUE
    }
  }
  flags
}

#' Summarize why a study offers only partial replication (yaml + optional audit)
#'
#' Driven by step \code{incomplete:} / \code{requires_engine:} /
#' \code{blocked_reason:} fields, optionally enriched with the latest registry
#' \code{audit_latest.rds} failures and timeouts. Used by Shiny for a one-shot
#' notice when a study is selected.
#'
#' @param meta Parsed replication metadata.
#' @param doi Optional DOI for registry audit lookup.
#' @param registry_root Optional local registry checkout.
#' @param include_registry_audit When \code{TRUE}, merge latest audit snapshot.
#' @return List with \code{partial}, \code{message}, \code{required_engines},
#'   \code{incomplete_ids}, \code{incomplete_n}, \code{audit_failed},
#'   \code{audit_timed_out}.
#' @keywords internal
study_partial_replication_notice <- function(
  meta,
  doi = NULL,
  registry_root = NULL,
  include_registry_audit = TRUE
) {
  empty <- list(
    partial = FALSE,
    message = NULL,
    required_engines = character(0),
    incomplete_ids = character(0),
    incomplete_n = 0L,
    audit_failed = 0L,
    audit_timed_out = 0L
  )
  if (is.null(meta) || !is.list(meta)) {
    return(empty)
  }

  entries <- tryCatch(collect_study_step_entries(meta), error = function(e) list())
  incomplete <- entries[vapply(entries, function(x) {
    isTRUE(x$incomplete %||% FALSE)
  }, logical(1))]
  incomplete_ids <- vapply(incomplete, function(x) {
    as.character(x$id[[1]] %||% x$id %||% "")
  }, character(1))
  incomplete_ids <- incomplete_ids[nzchar(incomplete_ids)]
  engines <- study_required_system_engines(meta)
  data_classes <- study_data_unavailable_classes(meta)

  audit_failed <- 0L
  audit_timed_out <- 0L
  if (isTRUE(include_registry_audit) && !is.null(doi) && nzchar(as.character(doi))) {
    reg <- tryCatch(
      study_registry_audit_results(doi, registry_root = registry_root),
      error = function(e) NULL
    )
    if (!is.null(reg) && isTRUE(reg$available) && !isTRUE(reg$not_in_audit)) {
      audit_failed <- as.integer(reg$failed %||% 0L)
      audit_timed_out <- as.integer(reg$timed_out %||% 0L)
    }
  }

  incomplete_n <- length(incomplete_ids)
  msg <- format_partial_replication_message(
    engines = engines,
    incomplete_n = incomplete_n,
    audit_failed = audit_failed,
    audit_timed_out = audit_timed_out,
    data_unavailable = data_classes
  )
  partial <- !is.null(msg) && nzchar(msg)
  list(
    partial = partial,
    message = msg,
    required_engines = engines,
    data_unavailable = data_classes,
    incomplete_ids = incomplete_ids,
    incomplete_n = incomplete_n,
    audit_failed = audit_failed,
    audit_timed_out = audit_timed_out
  )
}

#' Whether a Shiny step is suitable for default selection on study open
#'
#' Prefer steps where Display would work: baked output present, or a normal
#' runnable step (not \code{data_unavailable:} / missing-engine / incomplete
#' with no displayable output).
#'
#' @param entry Step list (yaml entry or Shiny row fields as a list).
#' @param output_exists Whether a display artifact exists.
#' @param audit_skipped_engine Passed to [classify_shiny_run_gap()].
#' @param engine_available Passed to [classify_shiny_run_gap()].
#' @return Logical.
#' @keywords internal
shiny_step_default_available <- function(
  entry,
  output_exists = FALSE,
  audit_skipped_engine = FALSE,
  engine_available = NULL
) {
  if (isTRUE(output_exists)) {
    return(TRUE)
  }
  gap <- classify_shiny_run_gap(
    entry,
    output_exists = FALSE,
    audit_skipped_engine = isTRUE(audit_skipped_engine),
    engine_available = engine_available
  )
  if (!is.null(gap$kind)) {
    return(FALSE)
  }
  incomplete <- isTRUE(entry$incomplete[[1]] %||% entry$incomplete %||% FALSE)
  !incomplete
}

#' First replication row suitable for Shiny default selection
#'
#' Walks \code{replications_df} in order and returns the first row where
#' \code{shiny_step_default_available()} is true. Falls back to row 1 when none
#' qualify (or the frame is empty / NULL).
#'
#' @param replications_df Data frame from Shiny \code{replications_to_df()}.
#' @param doi Study DOI / key (for artifact lookup).
#' @param folder Optional local registry / study folder.
#' @param repo Optional study repo slug.
#' @param language_for_row Optional function \code{function(row) -> engine}.
#' @param resolve_id Optional function \code{function(row, engine) -> step id}.
#' @return One-row data frame, or \code{NULL}.
#' @keywords internal
first_available_replication_row <- function(
  replications_df,
  doi,
  folder = NULL,
  repo = NULL,
  language_for_row = NULL,
  resolve_id = NULL
) {
  if (is.null(replications_df) || !is.data.frame(replications_df) ||
      nrow(replications_df) < 1L) {
    return(NULL)
  }
  if (!is.function(resolve_id)) {
    resolve_id <- function(row, engine) {
      as.character(row$id[[1]] %||% row$id %||% "")
    }
  }
  if (!is.function(language_for_row)) {
    language_for_row <- function(row) {
      if (!is.na(row$r_id[[1]] %||% NA_character_) &&
          nzchar(as.character(row$r_id[[1]]))) {
        return("r")
      }
      if (!is.na(row$stata_id[[1]] %||% NA_character_) &&
          nzchar(as.character(row$stata_id[[1]]))) {
        return("stata")
      }
      if (!is.na(row$python_id[[1]] %||% NA_character_) &&
          nzchar(as.character(row$python_id[[1]]))) {
        return("python")
      }
      "r"
    }
  }

  for (i in seq_len(nrow(replications_df))) {
    row <- replications_df[i, , drop = FALSE]
    eng <- language_for_row(row)
    resolved_id <- as.character(resolve_id(row, eng) %||% "")
    if (!nzchar(resolved_id)) {
      resolved_id <- as.character(row$id[[1]] %||% row$group[[1]] %||% "")
    }
    incomplete <- isTRUE(row$incomplete[[1]] %||% FALSE)
    req_eng <- tolower(trimws(as.character(row$requires_engine[[1]] %||% "")))
    data_tok <- tolower(trimws(as.character(row$data_unavailable[[1]] %||% "")))
    needs_probe <- incomplete || nzchar(req_eng) || nzchar(data_tok)

    output_exists <- FALSE
    audit_engine_skip <- FALSE
    engine_available <- NULL
    if (needs_probe && nzchar(as.character(doi %||% ""))) {
      output_exists <- tryCatch(
        step_display_output_exists(
          doi,
          resolved_id,
          folder = folder,
          repo = repo,
          language = eng
        ),
        error = function(e) FALSE
      )
      if (nzchar(req_eng) && !req_eng %in% c("r", "stata", "python")) {
        engine_available <- tryCatch(
          system_engine_available(req_eng),
          error = function(e) NULL
        )
        audit_hit <- tryCatch(
          lookup_replication_audit_engine_skip(
            doi,
            resolved_id,
            engine = eng
          ),
          error = function(e) NULL
        )
        audit_engine_skip <- isTRUE(audit_hit$skipped_engine)
      }
    }

    entry <- list(
      id = resolved_id,
      label = as.character(row$label[[1]] %||% row$group[[1]] %||% resolved_id),
      incomplete = incomplete,
      requires_engine = req_eng,
      data_unavailable = data_tok,
      blocked_reason = as.character(row$blocked_reason[[1]] %||% "")
    )
    if (shiny_step_default_available(
      entry,
      output_exists = isTRUE(output_exists),
      audit_skipped_engine = isTRUE(audit_engine_skip),
      engine_available = engine_available
    )) {
      return(row)
    }
  }

  replications_df[1, , drop = FALSE]
}

#' Whether any declared display output for a step already exists
#' @keywords internal
step_display_output_exists <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  meta <- tryCatch(
    get_replication_meta(doi, repo = repo, folder = folder),
    error = function(e) NULL
  )
  if (!is.null(meta)) {
    entry <- tryCatch(
      find_replication_entry(meta, what, language = language),
      error = function(e) NULL
    )
    # Pattern B Dataverse access: Display always has a yaml-backed summary.
    if (!is.null(entry) && is_dataverse_file_access_prep_step(entry, meta = meta)) {
      return(TRUE)
    }
    if (!is.null(entry) && is_dataverse_access_prep_step(entry, meta, ctx = NULL)) {
      return(TRUE)
    }
  }
  cands <- tryCatch(
    artifact_lookup_candidates(doi, what, repo = repo, folder = folder, language = language),
    error = function(e) character(0)
  )
  if (!length(cands)) {
    return(FALSE)
  }
  for (path in cands) {
    if (grepl("^https?://", path, ignore.case = TRUE)) {
      resp <- tryCatch(
        httr::HEAD(path, httr::user_agent("replicateEverything"), httr::timeout(8)),
        error = function(e) NULL
      )
      if (!is.null(resp) && httr::status_code(resp) < 400L) {
        return(TRUE)
      }
    } else if (file.exists(path)) {
      return(TRUE)
    }
  }
  FALSE
}

#' Stop with a clear, informative message when a step cannot be created
#' @keywords internal
stop_if_step_blocked <- function(meta, what, output_exists = NULL) {
  if (is.null(step_blocked_reason(meta, what))) {
    return(invisible(NULL))
  }
  if (is.null(output_exists)) {
    output_exists <- FALSE
    doi <- meta$paper$doi %||% meta$doi %||% NULL
    if (!is.null(doi) && nzchar(as.character(doi))) {
      output_exists <- tryCatch(
        step_display_output_exists(doi, what),
        error = function(e) FALSE
      )
    }
  }
  msg <- step_missing_engine_message(meta, what, output_exists = isTRUE(output_exists))
  stop(msg %||% "This object cannot be created.", call. = FALSE)
}

#' @keywords internal
run_replication_one <- function(
  doi,
  what,
  language = NULL,
  given = "parents",
  force = TRUE,
  install_deps = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  stop_if_step_blocked(meta, what)
  if (is_package_replication(meta)) {
    result <- render_replication(
      doi,
      what,
      language = language,
      install_deps = install_deps,
      repo = repo,
      folder = folder,
      force = force
    )
    object <- replication_object(result)
    apply_format <- isTRUE(format) || identical(format, "if_available")
    if (apply_format && isTRUE(result$has_format)) {
      object <- format_for_display(
        object,
        doi,
        what,
        language = language,
        install_deps = install_deps,
        repo = repo,
        folder = folder
      )
    }
    print(object)
    return(invisible(object))
  }

  prepared <- prepare_study_run(
    doi,
    what,
    given = given,
    format = format,
    force = force,
    repo = repo,
    folder = folder
  )
  executed <- execute_study_plan(
    prepared$plan,
    doi,
    meta = prepared$meta,
    ctx = prepared$ctx,
    language = language,
    install_deps = install_deps,
    force = force,
    format = format,
    repo = repo,
    folder = folder
  )
  result <- executed$result
  object <- replication_object(result)

  apply_format <- isTRUE(format) || identical(format, "if_available")
  if (apply_format && isTRUE(result$has_format)) {
    object <- format_for_display(
      object,
      doi,
      what,
      language = language,
      install_deps = install_deps,
      repo = repo,
      folder = folder
    )
  }

  if (!isTRUE(getOption("replicateEverything.quiet_run", FALSE))) {
    print(object)
  }
  invisible(object)
}

#' Step ids to run for \code{what = "everything"} (excludes format children)
#' @keywords internal
study_everything_step_ids <- function(meta) {
  steps <- normalize_study_steps(meta)
  if (length(steps) == 0L) {
    return(character(0))
  }
  graph <- study_step_graph(steps)
  ids <- graph$ids[!graph$types %in% c("format")]
  if (length(ids) == 0L) {
    return(character(0))
  }
  topological_step_sort(ids, graph)
}

#' @keywords internal
run_all_replications <- function(
  doi,
  language = NULL,
  given = "nothing",
  force = TRUE,
  install_deps = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
) {
  doi_key <- prepare_doi_for_replication(doi)
  meta <- get_replication_meta(doi_key, repo = repo, folder = folder)

  message("Replicating: ", meta$paper$title %||% doi_key)
  message("")

  if (is_package_replication(meta)) {
    groups <- list_replication_groups_impl(meta, language = language)
    results <- list()
    for (rep in groups) {
      id <- replication_logical_id(rep)
      message("Running: ", id)
      results[[id]] <- run_replication_one(
        doi_key,
        id,
        language = language,
        given = given,
        force = force,
        install_deps = install_deps,
        format = format,
        repo = repo,
        folder = folder
      )
    }
    names(results) <- vapply(groups, replication_logical_id, character(1))
    return(invisible(results))
  }

  step_ids <- study_everything_step_ids(meta)
  if (length(step_ids) == 0L) {
    groups <- list_replication_groups_impl(
      meta,
      language = language
    )
    step_ids <- vapply(groups, replication_logical_id, character(1))
  }

  results <- list()
  for (step_id in step_ids) {
    reason <- step_blocked_reason(meta, step_id)
    if (!is.null(reason)) {
      message("Skipping ", step_id, ": this object cannot be created because of: ", reason)
      results[[step_id]] <- structure(
        list(id = step_id, blocked_reason = reason),
        class = "replication_step_blocked"
      )
      next
    }
    message("Running: ", step_id)
    results[[step_id]] <- run_replication_one(
      doi_key,
      step_id,
      language = language,
      given = given,
      force = force,
      install_deps = install_deps,
      format = format,
      repo = repo,
      folder = folder
    )
  }

  invisible(results)
}

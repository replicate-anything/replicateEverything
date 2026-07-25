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

#' User-facing blocked-step message, distinguishing absent vs baked-but-blocked
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
  if (!is.null(engine)) {
    return(missing_engine_message(
      label,
      engine,
      mode = if (isTRUE(output_exists)) "not_reproducible" else "not_available"
    ))
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

#' Whether any declared display output for a step already exists
#' @keywords internal
step_display_output_exists <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
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

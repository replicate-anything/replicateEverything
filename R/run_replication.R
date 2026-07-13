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
#'   [resolve_doi_input()]).
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
#' @param force Logical. Re-run steps even when outputs already exist.
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
#' }
#'
#' @export
run_replication <- function(
  doi,
  what,
  language = NULL,
  given = NULL,
  force = FALSE,
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

#' @keywords internal
run_replication_one <- function(
  doi,
  what,
  language = NULL,
  given = "parents",
  force = FALSE,
  install_deps = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
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
  force = FALSE,
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

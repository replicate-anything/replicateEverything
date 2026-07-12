#' Run a single replication or all replications for a paper
#'
#' Executes a specific replication (figure or table) for a paper, or every
#' logical group when `what = "everything"`.
#'
#' By default returns the raw analysis object (e.g. a \code{glm} or \code{ggplot}).
#' Set \code{format = TRUE} or \code{format = "if_available"} to apply the
#' registered \code{format_*} step when \code{replication.yml} defines one
#' (same step used for display outputs and Shiny).
#'
#' @param doi Character. DOI, registry handle, or local study path (see
#'   [resolve_doi_input()]).
#' @param what Character. Replication identifier (logical id, e.g. \code{"tab_1"}),
#'   or \code{"everything"} to run all tables and figures.
#' @param language Optional \code{"R"}, \code{"stata"}, or \code{"python"}. When
#'   omitted and the replication has only one engine, that engine is used
#'   automatically. When both R and Stata exist for the same logical id, R is
#'   preferred unless \code{language} is set.
#' @param given Assumed-complete steps. \code{"parents"} (default) requires
#'   immediate parent outputs to exist; \code{"nothing"} runs the full upstream
#'   DAG; or a character vector of step ids (must include all ancestors of each
#'   listed step).
#' @param force Logical. Re-run steps even when outputs already exist.
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#' @param format Logical or \code{"if_available"}. Apply display formatting when
#'   available. Ignored when \code{what = "everything"} unless set explicitly.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return For a single replication, the analysis or formatted object. For
#'   \code{what = "everything"}, a named list of such objects (invisibly).
#'
#' @examples
#' \dontrun{
#' run_replication("10.1177/00491241211036161", "fig_1")
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
  given = "parents",
  force = FALSE,
  install_deps = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
) {
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

  print(object)
  invisible(object)
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

  message("Replicating: ", meta$paper$title)
  message("")

  groups <- list_replication_groups(
    doi_key,
    repo = repo,
    folder = folder,
    language = language
  )
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
  invisible(results)
}

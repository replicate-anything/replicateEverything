#' Execute a planned study run (ordered steps, memoized within session)
#'
#' @param plan Output of [plan_study_run()].
#' @param doi Study DOI or local path.
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @param language Optional engine for display steps.
#' @param install_deps Passed to [render_replication()].
#' @param force Re-run steps even when outputs exist.
#' @param format Whether to include format child in plan (already applied in plan).
#' @param repo Optional registry repo slug.
#' @param folder Optional registry folder.
#' @return List with final step result and named intermediate results.
#' @keywords internal
execute_study_plan <- function(
  plan,
  doi,
  meta,
  ctx,
  language = NULL,
  install_deps = FALSE,
  force = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
) {
  steps <- normalize_study_steps(meta)
  graph <- study_step_graph(steps)
  step_by_id <- setNames(steps, vapply(steps, function(x) as.character(x$id), character(1)))
  results <- list()
  executed <- character(0)
  run_engines <- study_engines_for_plan(meta, plan)

  for (step_id in plan$step_ids) {
    if (step_id %in% executed) {
      next
    }
    step <- step_by_id[[step_id]]
    if (is.null(step)) {
      stop("Step '", step_id, "' missing from study metadata.", call. = FALSE)
    }
    is_format <- identical(as.character(step$type), "format")
    if (!isTRUE(force) && !is_format && step_outputs_ready(step, ctx, meta = meta)) {
      message("Using existing output for step: ", step_id)
      results[[step_id]] <- list(status = "cached", id = step_id)
      executed <- c(executed, step_id)
      next
    }
    lang <- if (is_format) language else NULL
    if (!is_format && !is.null(language)) {
      lang <- language
    }
    message("Running step: ", step_id)
    result <- render_replication_step(
      doi,
      step_id,
      meta = meta,
      ctx = ctx,
      language = lang,
      install_deps = install_deps,
      repo = repo,
      folder = folder,
      skip_prep = TRUE,
      force = force,
      engines = run_engines
    )
    results[[step_id]] <- result
    executed <- c(executed, step_id)
  }

  target_id <- plan$target_id
  if (!target_id %in% executed || isTRUE(force)) {
    result <- render_replication_step(
      doi,
      target_id,
      meta = meta,
      ctx = ctx,
      language = language,
      install_deps = install_deps,
      repo = repo,
      folder = folder,
      skip_prep = TRUE,
      force = force,
      engines = run_engines
    )
    results[[target_id]] <- result
  } else {
    cached <- results[[target_id]]
    if (is.list(cached) && identical(cached$status, "cached")) {
      result <- render_replication_step(
        doi,
        target_id,
        meta = meta,
        ctx = ctx,
        language = language,
        install_deps = install_deps,
        repo = repo,
        folder = folder,
        skip_prep = TRUE,
        force = FALSE,
        engines = run_engines
      )
    } else {
      result <- cached
    }
  }

  list(
    target_id = target_id,
    result = result,
    steps = results
  )
}

#' Render one step without legacy prep dependency runner
#' @keywords internal
render_replication_step <- function(
  doi,
  what,
  meta = NULL,
  ctx = NULL,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  skip_prep = FALSE,
  force = FALSE,
  engines = NULL
) {
  if (is.null(meta)) {
    meta <- get_replication_meta(doi, repo = repo, folder = folder)
  }
  if (is.null(ctx)) {
    ctx <- paper_context(doi, repo = repo, folder = folder)
  }
  render_replication(
    doi,
    what,
    language = language,
    install_deps = install_deps,
    repo = repo,
    folder = folder,
    skip_prep = skip_prep,
    force = force,
    meta = meta,
    ctx = ctx,
    engines = engines
  )
}

#' Prepare and validate a study run plan
#' @keywords internal
prepare_study_run <- function(
  doi,
  what,
  given = "parents",
  format = FALSE,
  force = FALSE,
  repo = NULL,
  folder = NULL
) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  steps <- normalize_study_steps(meta)
  graph <- study_step_graph(steps)
  validate_study_step_graph(graph)
  plan <- plan_study_run(what, given, format, graph)

  given_norm <- normalize_given_argument(given)
  if (identical(given_norm, "parents")) {
    assert_parents_ready(what, graph, ctx, meta, force = force)
  } else if (length(given_norm) > 0L && !identical(given_norm, "nothing")) {
    assert_given_outputs_ready(plan$given_ids, graph, ctx, meta, force = force)
  }

  list(meta = meta, ctx = ctx, graph = graph, plan = plan)
}

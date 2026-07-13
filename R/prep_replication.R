#' Whether a yaml entry is a pipeline / prep step
#'
#' @param rep Replication or prep entry from \code{replication.yml}.
#' @return Logical scalar.
#' @keywords internal
is_prep_entry <- function(rep) {
  type <- tolower(as.character(rep$type %||% ""))
  if (type %in% c("table", "figure", "format")) {
    return(FALSE)
  }
  if (type %in% c("step", "prep", "pipeline", "transform")) {
    return(TRUE)
  }
  !is.null(rep$output) &&
    is.null(rep$artifact) &&
    nzchar(as.character(rep$output %||% ""))
}

#' List pipeline prep steps for a paper
#'
#' Superseded by [list_replications()] with `include = "pipeline"`.
#'
#' @inheritParams list_replications
#' @return A list of prep step entries.
#' @export
list_prep_steps <- function(doi, repo = NULL, folder = NULL) {
  .Deprecated("list_replications(..., include = \"pipeline\")")
  list_replications(doi, repo = repo, folder = folder, include = "pipeline")
}

#' Resolve a prep step output path on disk
#'
#' @param prep Prep entry from \code{replication.yml}.
#' @param ctx Paper context from \code{paper_context()}.
#' @param meta Optional parsed replication metadata.
#' @keywords internal
prep_output_path <- function(prep, ctx, meta = NULL) {
  p <- step_primary_output_path(prep, ctx, meta = meta)
  if (!is.null(p) && nzchar(p)) {
    return(p)
  }
  out <- prep$output %||% prep$artifact %||% NULL
  if (is.null(out) || !nzchar(as.character(out))) {
    return(NULL)
  }
  out <- as.character(out[[1]] %||% out)
  resolve_registry_file(out, ctx, meta = meta, local_only = TRUE)
}

#' Whether a prep step output already exists
#'
#' @inheritParams prep_output_path
#' @keywords internal
prep_output_ready <- function(prep, ctx, meta = NULL) {
  path <- prep_output_path(prep, ctx, meta = meta)
  !is.null(path) && nzchar(path) && file.exists(path)
}

#' Find a prep entry by id
#'
#' @param meta Parsed replication metadata.
#' @param step_id Prep step identifier.
#' @keywords internal
find_prep_entry <- function(meta, step_id) {
  step_id <- as.character(step_id)
  pipeline <- collect_study_step_entries(meta)
  pipeline <- pipeline[vapply(pipeline, is_prep_entry, logical(1))]
  matches <- pipeline[vapply(pipeline, function(x) {
    identical(as.character(x$id), step_id)
  }, logical(1))]
  if (length(matches) == 0L) {
    steps <- meta$prep %||% list()
    matches <- steps[vapply(steps, function(x) {
      identical(as.character(x$id), step_id)
    }, logical(1))]
  }
  if (length(matches) == 0L) {
    stop("Prep step ", step_id, " not found in metadata", call. = FALSE)
  }
  matches[[1]]
}

#' Preview a processed data file (head rows)
#'
#' @param path Local file path.
#' @param n Maximum rows to read.
#' @keywords internal
preview_data_file <- function(path, n = 6L) {
  if (!file.exists(path)) {
    stop("Processed data file not found: ", path, call. = FALSE)
  }
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("csv")) {
    return(utils::read.csv(path, nrows = n, stringsAsFactors = FALSE))
  }
  if (ext %in% c("dta") && requireNamespace("haven", quietly = TRUE)) {
    return(haven::read_dta(path, n_max = n))
  }
  if (ext %in% c("rds")) {
    obj <- readRDS(path)
    if (is.data.frame(obj)) {
      return(utils::head(obj, n))
    }
    return(obj)
  }
  structure(
    list(path = path, note = "Preview not available for this file type."),
    class = "prep_output_preview"
  )
}

#' Run a single prep step
#'
#' Executes a pipeline step (Stata, R, or Python), writes \code{output} when
#' configured, and returns a preview object (typically the head of a data frame).
#'
#' @inheritParams run_replication
#' @param what Prep step id (e.g. \code{"construct_analysis_dataset"}).
#' @return A data preview, file path character vector, or replication result.
#' @export
run_prep_step <- function(
  doi,
  what,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  force = FALSE
) {
  doi <- prepare_doi_for_replication(doi)
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  prep <- find_prep_entry(meta, what)

  if (!force && prep_output_ready(prep, ctx, meta = meta)) {
    path <- prep_output_path(prep, ctx, meta = meta)
    message("Using existing processed file: ", path)
    return(preview_data_file(path))
  }

  result <- render_replication(
    doi,
    what,
    install_deps = install_deps,
    repo = repo,
    folder = folder
  )
  invisible(replicate_fn_result_object(result))
}

#' @keywords internal
replicate_fn_result_object <- function(result) {
  if (inherits(result, "replication_result")) {
    return(result$object)
  }
  result
}

#' Required prep step ids for a replication entry
#'
#' @param rep Replication entry.
#' @keywords internal
replication_requires_prep <- function(rep) {
  req <- rep$requires %||% rep$depends_on %||% list()
  if (length(req) == 0L) {
    return(character(0))
  }
  vapply(req, function(x) as.character(x), character(1))
}

#' Collect prep step ids required by replication entries (transitive)
#'
#' @param meta Parsed replication metadata.
#' @param replications List of replication entries.
#' @return Character vector of prep ids in \code{prep:} block order.
#' @keywords internal
collect_required_prep_ids <- function(meta, replications) {
  if (length(replications) == 0L) {
    return(character(0))
  }
  prep_ids <- character(0)
  queue <- unique(unlist(lapply(replications, replication_requires_prep), use.names = FALSE))
  while (length(queue) > 0L) {
    id <- queue[[1L]]
    queue <- queue[-1L]
    if (id %in% prep_ids) {
      next
    }
    prep <- tryCatch(find_prep_entry(meta, id), error = function(e) NULL)
    if (is.null(prep)) {
      next
    }
    prep_ids <- c(prep_ids, id)
    queue <- unique(c(replication_requires_prep(prep), queue))
  }
  all_prep <- meta$prep %||% list()
  if (length(all_prep) == 0L) {
    return(prep_ids)
  }
  yaml_order <- vapply(all_prep, function(x) as.character(x$id), character(1))
  ordered <- prep_ids[prep_ids %in% yaml_order]
  ordered[order(match(ordered, yaml_order))]
}

#' Prep steps to run before building display artifacts
#'
#' When \code{display_reps} is \code{NULL}, returns every entry in \code{prep:}.
#' Otherwise returns only prep steps required by the given replications.
#'
#' @param meta Parsed replication metadata.
#' @param display_reps Optional list of table/figure entries being built.
#' @keywords internal
prep_steps_for_build <- function(meta, display_reps = NULL) {
  all_prep <- meta$prep %||% list()
  if (length(all_prep) == 0L) {
    return(list())
  }
  if (is.null(display_reps)) {
    return(all_prep)
  }
  required_ids <- collect_required_prep_ids(meta, display_reps)
  if (length(required_ids) == 0L) {
    return(list())
  }
  all_prep[vapply(all_prep, function(x) {
    as.character(x$id) %in% required_ids
  }, logical(1))]
}

#' Relative path for prep output in build manifests
#' @keywords internal
prep_manifest_output_path <- function(path, root = NULL) {
  if (is.null(path) || length(path) == 0L || !nzchar(as.character(path[[1]]))) {
    return(NULL)
  }
  path <- normalizePath(as.character(path[[1]]), winslash = "/", mustWork = FALSE)
  if (!is.null(root) && nzchar(root)) {
    root <- normalizePath(root, winslash = "/", mustWork = FALSE)
    prefix <- paste0(root, "/")
    if (startsWith(path, prefix)) {
      return(sub(paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", root), "/?"), "", path))
    }
  }
  path
}

#' Run pipeline prep steps during artifact builds
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @param doi Normalized DOI.
#' @param prep_steps List of prep entries to run.
#' @param install_deps Passed to \code{render_replication()}.
#' @param force Re-run prep even when outputs already exist.
#' @param study_root Optional study or package root for portable manifest paths.
#' @return List with \code{statuses} (named list) and \code{failures}.
#' @keywords internal
run_build_prep_steps <- function(
  meta,
  ctx,
  doi,
  prep_steps,
  install_deps = FALSE,
  force = FALSE,
  study_root = NULL
) {
  statuses <- list()
  failures <- character(0)
  if (length(prep_steps) == 0L) {
    return(list(statuses = statuses, failures = failures))
  }

  for (prep in prep_steps) {
    step_id <- as.character(prep$id)
    message("Running prep step: ", step_id, " ...")
    status <- tryCatch({
      if (!force && prep_output_ready(prep, ctx, meta = meta)) {
        path <- prep_output_path(prep, ctx, meta = meta)
        list(
          status = "cached",
          output = prep_manifest_output_path(path, study_root)
        )
      } else {
        result <- render_replication(
          doi,
          step_id,
          install_deps = install_deps,
          repo = ctx$repo %||% NULL,
          folder = ctx$folder %||% NULL
        )
        path <- result$output_path %||% prep_output_path(prep, ctx, meta = meta)
        list(
          status = "ok",
          output = prep_manifest_output_path(path, study_root),
          source = result$source %||% "prep"
        )
      }
    }, error = function(e) {
      msg <- if (!is.null(study_root) && nzchar(study_root)) {
        portable_path_in_text(conditionMessage(e), study_root)
      } else {
        conditionMessage(e)
      }
      failures <<- c(failures, paste0(step_id, ": ", msg))
      list(status = "error", message = msg)
    })
    statuses[[step_id]] <- status
  }

  list(statuses = statuses, failures = failures)
}

#' Run missing upstream DAG steps before a display replication
#'
#' When a study uses the unified \code{steps:} block, display steps declare
#' \code{parents:} rather than legacy \code{requires:}. This runs any ancestor
#' transform steps whose outputs are not yet present.
#'
#' @param meta Parsed metadata.
#' @param rep Replication entry.
#' @param ctx Paper context.
#' @param doi Study DOI or handle.
#' @param install_deps Passed to step runners.
#' @param force Re-run steps even when outputs exist.
#' @param repo Optional registry repo slug.
#' @param folder Optional registry folder.
#' @keywords internal
ensure_study_ancestor_steps <- function(
  meta,
  rep,
  ctx,
  doi,
  install_deps = FALSE,
  force = FALSE,
  repo = NULL,
  folder = NULL
) {
  steps <- normalize_study_steps(meta)
  if (length(steps) == 0L) {
    return(invisible(NULL))
  }
  target_id <- as.character(rep$id %||% "")
  if (!nzchar(target_id)) {
    return(invisible(NULL))
  }
  graph <- study_step_graph(steps)
  if (!target_id %in% graph$ids) {
    return(invisible(NULL))
  }
  ancestors <- topological_step_sort(step_ancestors(target_id, graph), graph)
  if (length(ancestors) == 0L) {
    return(invisible(NULL))
  }
  step_by_id <- setNames(steps, vapply(steps, function(x) as.character(x$id), character(1)))
  repo <- repo %||% ctx$repo %||% NULL
  folder <- folder %||% ctx$folder %||% NULL
  for (step_id in ancestors) {
    step <- step_by_id[[step_id]]
    run_ctx <- step_run_context(step, meta, ctx)
    if (!isTRUE(force) && step_outputs_ready(step, run_ctx, meta = meta)) {
      next
    }
    message("Running upstream step: ", step_id)
    render_replication_step(
      doi,
      step_id,
      meta = meta,
      ctx = ctx,
      install_deps = install_deps,
      repo = repo,
      folder = folder,
      skip_prep = TRUE,
      force = force
    )
  }
  invisible(NULL)
}

#' Ensure prep dependencies exist before running a replication
#'
#' @param meta Parsed metadata.
#' @param rep Replication entry.
#' @param ctx Paper context.
#' @param doi Study DOI or handle.
#' @param install_deps Passed to prep runners.
#' @param force Re-run prep even when outputs exist.
#' @keywords internal
ensure_prep_dependencies <- function(
  meta,
  rep,
  ctx,
  doi,
  install_deps = FALSE,
  force = FALSE
) {
  req <- replication_requires_prep(rep)
  if (length(req) == 0L) {
    return(invisible(NULL))
  }
  for (step_id in req) {
    prep <- find_prep_entry(meta, step_id)
    if (!force && prep_output_ready(prep, ctx, meta = meta)) {
      next
    }
    message("Running required prep step: ", step_id)
    render_replication(
      doi,
      step_id,
      install_deps = install_deps,
      repo = ctx$repo %||% NULL,
      folder = ctx$folder %||% NULL
    )
  }
  invisible(NULL)
}

#' Whether a yaml entry is a pipeline / prep step
#'
#' @param rep Replication or prep entry from \code{replication.yml}.
#' @return Logical scalar.
#' @keywords internal
is_prep_entry <- function(rep) {
  type <- tolower(as.character(rep$type %||% ""))
  if (type %in% c("step", "prep", "pipeline")) {
    return(TRUE)
  }
  !is.null(rep$output) && nzchar(as.character(rep$output %||% ""))
}

#' List pipeline prep steps for a paper
#'
#' Returns entries from the \code{prep:} block in \code{replication.yml}.
#'
#' @inheritParams list_replications
#' @return A list of prep step entries.
#' @export
list_prep_steps <- function(doi, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  prep <- meta$prep %||% list()
  if (length(prep) > 0L) {
    return(prep)
  }
  if (is_folder_study_replication(meta)) {
    ctx <- paper_context(doi, repo = repo, folder = folder)
    study_meta <- fetch_folder_study_replication_yaml(meta, ctx)
    if (!is.null(study_meta)) {
      return(study_meta$prep %||% list())
    }
  }
  if (is_package_replication(meta)) {
    ctx <- paper_context(doi, repo = repo, folder = folder)
    pkg_meta <- fetch_package_replication_yaml(meta, ctx)
    if (!is.null(pkg_meta)) {
      return(pkg_meta$prep %||% list())
    }
  }
  list()
}

#' Resolve a prep step output path on disk
#'
#' @param prep Prep entry from \code{replication.yml}.
#' @param ctx Paper context from \code{paper_context()}.
#' @param meta Optional parsed replication metadata.
#' @keywords internal
prep_output_path <- function(prep, ctx, meta = NULL) {
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
  steps <- meta$prep %||% list()
  matches <- steps[vapply(steps, function(x) identical(as.character(x$id), step_id), logical(1))]
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

#' Ensure prep dependencies exist before running a replication
#'
#' @param meta Parsed metadata.
#' @param rep Replication entry.
#' @param ctx Paper context.
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

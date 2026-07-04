#' Check whether a replication entry defines a separate format step
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @keywords internal
format_specified <- function(rep) {
  fmt <- rep$format
  !is.null(fmt) && length(fmt) > 0 && nzchar(as.character(fmt[[1]]))
}

#' Default format function name for a replication id
#'
#' @param rep_id Replication identifier.
#' @keywords internal
default_format_name <- function(rep_id) {
  paste0("format_", gsub("[^a-zA-Z0-9_]", "_", rep_id))
}

#' Resolve the format function name for a replication entry
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @keywords internal
format_function_name <- function(rep) {
  if (!format_specified(rep)) {
    return(NULL)
  }
  fmt <- as.character(rep$format[[1]])
  if (grepl("[/\\\\]", fmt) || grepl("\\.R$", fmt, ignore.case = TRUE)) {
    return(default_format_name(rep$id))
  }
  fmt
}

#' Resolve optional path to a format script
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @keywords internal
format_script_path <- function(rep) {
  if (!format_specified(rep)) {
    return(NULL)
  }
  fmt <- as.character(rep$format[[1]])
  if (grepl("[/\\\\]", fmt) || grepl("\\.R$", fmt, ignore.case = TRUE)) {
    return(fmt)
  }
  NULL
}

#' Source replication and optional format scripts into an environment
#'
#' @keywords internal
source_replication_scripts <- function(rep, ctx, env, install_deps = FALSE, include_format = TRUE, meta = NULL) {
  code_path <- rep$code
  if (is.null(code_path) || !nzchar(code_path)) {
    stop("Replication ", rep$id, " is missing a code path.")
  }

  tmp_code <- resolve_registry_file(code_path, ctx, meta = meta)
  if (!grepl("\\.do$", code_path, ignore.case = TRUE)) {
    source_replication_functions(tmp_code, env, install_deps = install_deps)
  }

  if (!include_format || !format_specified(rep)) {
    return(invisible(env))
  }

  fmt_path <- format_script_path(rep)
  if (!is.null(fmt_path) && normalizePath(fmt_path, winslash = "/", mustWork = FALSE) !=
      normalizePath(tmp_code, winslash = "/", mustWork = FALSE)) {
    tmp_format <- resolve_registry_file(fmt_path, ctx, meta = meta)
    source_replication_functions(tmp_format, env, install_deps = install_deps)
  }

  invisible(env)
}

#' Apply an optional format function to an analysis object
#'
#' When \code{replication.yml} defines \code{format}, the analysis object
#' (typically from \code{make_*}) is passed to \code{format_*} for display.
#' Otherwise the object is returned unchanged.
#'
#' @param object Analysis output to format.
#' @param doi Character. DOI of the paper.
#' @param what Replication identifier (logical id).
#' @param language Optional \code{"R"} or \code{"stata"}.
#' @param install_deps Logical. Install missing dependencies when \code{TRUE}.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @return Object suitable for display (often an HTML string or ggplot).
#'
#' @examples
#' \dontrun{
#' result <- render_replication("10.1177/00491241211036161", "fig_1")
#' format_for_display(replication_object(result), "10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
format_for_display <- function(
  object,
  doi,
  what,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
) {
  doi <- normalize_doi(doi)
  meta <- get_replication_meta(doi, repo = repo, folder = folder)

  # Package run_replication() already applies format_* ; registry stub yaml
  # may not list individual replications.
  if (is_package_replication(meta)) {
    return(object)
  }

  rep <- find_replication_entry(meta, what, language = language)

  if (!format_specified(rep)) {
    return(object)
  }

  if (inherits(object, "ggplot")) {
    return(object)
  }

  if (is.null(object)) {
    return(NULL)
  }

  if (is.character(object) && length(object) == 1L &&
      grepl("<table|<html|<!DOCTYPE|<pre", object, ignore.case = TRUE)) {
    return(object)
  }

  if (is_stata_replication(rep, meta$paper)) {
    object <- normalize_stata_result_object(object)
  }

  ensure_replication_dependencies(
    rep,
    paper_meta = meta$paper,
    install_missing = install_deps
  )

  ctx <- paper_context(doi, repo = repo, folder = folder)
  if (is_stata_replication(rep, meta$paper)) {
    ctx$local_root <- ensure_study_folder_local(meta, ctx)
  }
  env <- new.env(parent = globalenv())
  source_replication_scripts(rep, ctx, env, install_deps = install_deps, include_format = TRUE, meta = meta)

  fn_name <- format_function_name(rep)
  if (!exists(fn_name, envir = env, inherits = FALSE)) {
    stop(
      "Format function ", fn_name, " not found. ",
      "Define it in ", rep$code,
      if (!is.null(format_script_path(rep))) paste0(" or ", format_script_path(rep)) else "",
      "."
    )
  }

  fmt_fn <- get(fn_name, envir = env, inherits = FALSE)
  fmt_object <- if (is_stata_replication(rep, meta$paper)) {
    normalize_stata_result_object(object)
  } else {
    object
  }
  tryCatch(
    retry_with_missing_package(
      fmt_fn(fmt_object),
      install_missing = install_deps
    ),
    error = function(e) {
      if (!is_stata_replication(rep, meta$paper)) {
        stop(e)
      }
      path <- stata_result_path(fmt_object)
      if (!is.null(path) && file.exists(path) &&
          identical(stata_output_extension(path), "smcl")) {
        return(smcl_to_html(path))
      }
      stop(e)
    }
  )
}

#' Render a replication and apply formatting for display
#'
#' @inheritParams render_replication
#'
#' @examples
#' \dontrun{
#' render_for_display("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
render_for_display <- function(
  doi,
  what,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
) {
  result <- render_replication(
    doi,
    what,
    language = language,
    install_deps = install_deps,
    repo = repo,
    folder = folder
  )
  display <- format_for_display(
    replication_object(result),
    doi,
    what,
    language = language,
    install_deps = install_deps,
    repo = repo,
    folder = folder
  )
  result$display <- display
  result$display_format <- infer_result_format(display, result$type)
  result
}

#' @keywords internal
resolve_registry_file <- function(path, ctx, meta = NULL) {
  if (is.null(ctx$local_root) && !is.null(meta)) {
    ctx$local_root <- ensure_study_folder_local(meta, ctx)
  }
  if (!is.null(ctx$local_root)) {
    local_path <- file.path(ctx$local_root, path)
    if (file.exists(local_path)) {
      return(local_path)
    }
  }
  download_registry_file(paste0(ctx$base_url, "/", path))
}

#' Merge replication entries from the study package into registry stub metadata
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Updated metadata list.
#' @keywords internal
enrich_package_replication_meta <- function(meta, ctx) {
  if (!is_package_replication(meta)) {
    return(meta)
  }
  reps <- meta$replications %||% list()
  if (length(reps) > 0) {
    return(meta)
  }

  pkg_meta <- fetch_package_replication_yaml(meta, ctx)
  if (!is.null(pkg_meta)) {
    meta$replications <- pkg_meta$replications %||% list()
    if (length(meta$prep %||% list()) == 0) {
      meta$prep <- pkg_meta$prep %||% list()
    }
    return(meta)
  }

  pkg <- as.character(meta$paper$package[[1]])
  ensure_replication_package(pkg, meta = meta, ctx = ctx)
  if (replication_package_usable(pkg)) {
    pkg_meta <- tryCatch(
      read_package_replication_meta(pkg),
      error = function(e) NULL
    )
    if (!is.null(pkg_meta)) {
      meta$replications <- pkg_meta$replications %||% list()
      if (length(meta$prep %||% list()) == 0) {
        meta$prep <- pkg_meta$prep %||% list()
      }
      if (length(meta$steps %||% list()) == 0) {
        meta$steps <- pkg_meta$steps %||% list()
      }
    }
  }
  meta
}

#' Fetch replication metadata for a paper
#'
#' @param doi Character. DOI of the paper.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return Parsed \code{replication.yml} contents.
#' @keywords internal
get_replication_meta_impl <- function(doi, repo = NULL, folder = NULL) {
  doi <- prepare_doi_for_replication(doi)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  meta <- NULL

  registry_root <- getOption("replicateEverything.registry_root", NULL)
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    registry_root <- auto_detect_registry_root()
  }

  stub_path <- ctx$registry_stub_path %||% NULL
  if (is.null(stub_path) && !is.null(registry_root)) {
    stub_path <- registry_paper_yaml_path(registry_root, ctx$folder)
  }
  if (!is.null(stub_path) && file.exists(stub_path)) {
    meta <- tryCatch(yaml::read_yaml(stub_path), error = function(e) NULL)
  }

  if (is.null(meta)) {
    meta <- read_yaml_url(registry_paper_yaml_url(ctx$folder))
  }
  if (is.null(meta)) {
    legacy_url <- sprintf(
      "https://raw.githubusercontent.com/%s/main/studies/%s/replication.yml",
      DEFAULT_REGISTRY_REPO,
      ctx$folder
    )
    meta <- read_yaml_url(legacy_url)
  }

  if (is.null(meta) && isTRUE(ctx$is_folder_study)) {
    meta <- fetch_folder_study_replication_yaml(
      list(repo = ctx$materials_repo),
      ctx
    )
  }

  if (is.null(meta) && !is.null(ctx$local_root)) {
    local_yml <- file.path(ctx$local_root, "replication.yml")
    if (file.exists(local_yml)) {
      meta <- yaml::read_yaml(local_yml)
    }
  }

  if (is.null(meta) && grepl("^rep[-_]", doi)) {
    local_root <- resolve_local_study_folder(doi)
    if (!is.null(local_root)) {
      local_yml <- file.path(local_root, "replication.yml")
      if (file.exists(local_yml)) {
        meta <- yaml::read_yaml(local_yml)
        if (is.null(ctx$local_root)) {
          ctx$local_root <- local_root
        }
      }
    }
  }

  if (is.null(meta)) {
    monorepo <- sibling_monorepo_root()
    if (!is.null(monorepo)) {
      study_dir <- file.path(monorepo, study_folder_from_doi(doi))
      local_yml <- file.path(study_dir, "replication.yml")
      if (file.exists(local_yml)) {
        meta <- yaml::read_yaml(local_yml)
      }
    }
  }

  if (is.null(meta)) {
    study_dir <- resolve_local_study_folder(doi)
    if (!is.null(study_dir)) {
      local_yml <- file.path(study_dir, "replication.yml")
      if (file.exists(local_yml)) {
        meta <- yaml::read_yaml(local_yml)
      }
    }
  }

  if (is.null(meta)) {
    urls <- unique(c(
      paste0(ctx$base_url, "replication.yml"),
      paste0("https://raw.githubusercontent.com/", ctx$repo, "/main/replication.yml"),
      paste0("https://raw.githubusercontent.com/", ctx$repo, "/main/inst/replication.yml")
    ))
    for (meta_url in urls) {
      meta <- read_yaml_url(meta_url)
      if (!is.null(meta)) {
        break
      }
    }
  }

  if (is.null(meta)) {
    stop(
      "Could not load replication.yml for ", doi, ".\n",
      "This study is not on the remote registry yet. From your monorepo run:\n",
      "  devtools::load_all(\"replicateEverything\")\n",
      "  replicateEverything::configure_local_monorepo()\n",
      "Or set options(replicateEverything.registry_root = ..., ",
      "replicateEverything.study_folders_root = ..., ",
      "replicateEverything.use_sibling_packages = TRUE).",
      call. = FALSE
    )
  }

  meta <- enrich_package_replication_meta(meta, ctx)
  meta <- enrich_folder_study_replication_meta(meta, ctx)
  if (is_folder_study_replication(meta, ctx)) {
    local_root <- resolve_study_folder_path(meta, ctx)
    if (!is.null(local_root) && dir.exists(local_root)) {
      meta <- complete_folder_study_meta(meta, local_root)
    }
  }
  meta <- merge_extended_study_meta(meta, ctx)
  meta
}

get_replication_meta <- function(doi, repo = NULL, folder = NULL) {
  doi_key <- tryCatch(
    prepare_doi_for_replication(doi),
    error = function(e) normalize_doi(doi)
  )
  key <- paste(
    doi_key,
    repo %||% "",
    folder %||% "",
    sep = "\x1f"
  )
  if (!exists(key, envir = .replication_meta_cache, inherits = FALSE)) {
    assign(
      key,
      get_replication_meta_impl(doi, repo = repo, folder = folder),
      envir = .replication_meta_cache
    )
  }
  get(key, envir = .replication_meta_cache)
}

#' @keywords internal
.replication_meta_cache <- new.env(parent = emptyenv())

#' Join a registry base URL with a relative path without duplicate slashes.
#'
#' @param base Character base URL.
#' @param rel Character relative path.
#' @keywords internal
registry_url <- function(base, rel) {
  paste0(sub("/$", "", base), "/", sub("^/", "", rel))
}

#' Resolve a precomputed artifact under the registry study folder
#'
#' The artifact location comes from a single rule -- \code{study_artifact_rel_path()}
#' (first displayable path from \code{outputs:} in \code{replication.yml}, or the
#' type-based default). Builds write to that same path, so lookup is deterministic:
#' return the local file when present, otherwise the registry URL. Availability of
#' the remote file is decided by the actual fetch in \code{load_artifact_file_path()},
#' not by a separate existence probe.
#'
#' Package-backed studies ship display artifacts on the study package and are
#' resolved elsewhere (see \code{get_artifact_path()}).
#'
#' @param what Replication id (used only when \code{rep} is unavailable).
#' @param ctx Paper context.
#' @param rep Replication entry from \code{replication.yml}.
#' @param doi Unused; retained for backward compatibility.
#' @keywords internal
resolve_registry_artifact_path <- function(what, ctx, rep = NULL, doi = NULL) {
  if (is.null(rep)) {
    return(NULL)
  }
  for (rel in study_artifact_rel_candidates(rep)) {
    if (!is.null(ctx$local_root)) {
      local <- file.path(ctx$local_root, rel)
      if (file.exists(local)) {
        return(normalizePath(local, winslash = "/", mustWork = FALSE))
      }
    }
  }
  for (rel in study_artifact_rel_candidates(rep)) {
    url <- registry_url(ctx$base_url, rel)
    if (nzchar(url)) {
      return(url)
    }
  }
  NULL
}

#' @keywords internal
package_installed_artifact_path <- function(what, pkg, meta = NULL, ctx = NULL) {
  if (!is.null(meta) && !is.null(ctx)) {
    local_root <- resolve_replication_package_path(pkg, meta, ctx)
    art_dir <- study_artifact_dir(meta, ctx, installed = FALSE, package = pkg)
    if (!is.null(local_root) && !is.null(art_dir)) {
      for (ext in c("png", "html", "rds", "svg")) {
        path <- file.path(local_root, "inst", "report", "artifacts", paste0(what, ".", ext))
        if (file.exists(path)) {
          return(normalizePath(path, winslash = "/", mustWork = FALSE))
        }
      }
    }
  }
  if (!replication_package_usable(pkg)) {
    return(NULL)
  }
  art_dir <- if (!is.null(meta)) {
    study_artifact_dir(meta, ctx, installed = TRUE, package = pkg)
  } else {
    system.file("report", "artifacts", package = pkg)
  }
  if (is.null(art_dir) || !nzchar(art_dir)) {
    return(NULL)
  }
  for (ext in c("png", "html", "rds", "svg")) {
    path <- file.path(art_dir, paste0(what, ".", ext))
    if (file.exists(path)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }
  NULL
}

#' @keywords internal
artifact_content_missing <- function(x) {
  is.null(x) || (is.character(x) && length(x) == 1L && !nzchar(x))
}

#' Load artifact bytes from a local path or registry URL
#'
#' @param path Local path or HTTP(S) URL.
#' @keywords internal
load_artifact_file_path <- function(path) {
  if (artifact_content_missing(path)) {
    return(NULL)
  }
  if (grepl("^https?://", path, ignore.case = TRUE)) {
    ext <- tolower(tools::file_ext(path))
    resp <- tryCatch(
      httr::GET(
        path,
        httr::user_agent("replicateEverything"),
        httr::timeout(20)
      ),
      error = function(e) NULL
    )
    if (is.null(resp) || httr::status_code(resp) >= 400L) {
      return(NULL)
    }
    if (ext %in% c("png", "svg", "jpg", "jpeg")) {
      tmp <- tempfile(fileext = paste0(".", ext))
      writeBin(httr::content(resp, as = "raw"), tmp)
      return(tmp)
    }
    txt <- httr::content(resp, as = "text", encoding = "UTF-8")
    if (ext == "html") {
      return(normalize_html_table(paste(txt, collapse = "\n")))
    }
  }
  if (!file.exists(path)) {
    return(NULL)
  }
  read_artifact_file(path, tolower(tools::file_ext(path)))
}

#' Replication entries from a study package when the registry stub omits them
#'
#' @param meta Parsed replication metadata.
#' @return List of replication/prep entries.
#' @keywords internal
package_replication_entries <- function(meta) {
  if (!is_package_replication(meta)) {
    return(list())
  }
  pkg <- as.character(meta$paper$package[[1]])
  if (!requireNamespace(pkg, quietly = TRUE)) {
    return(list())
  }
  pkg_meta <- tryCatch(
    read_package_replication_meta(pkg),
    error = function(e) NULL
  )
  if (is.null(pkg_meta)) {
    return(list())
  }
  package_yaml_entries(pkg_meta)
}

#' Render a single replication
#'
#' Loads data, sources the replication script, and returns a typed result
#' envelope suitable for Shiny display or artifact generation.
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (logical id, e.g. \code{"tab_1"}).
#' @param language Optional \code{"R"} or \code{"stata"}.
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return A list with \code{id}, \code{type}, \code{object}, and \code{format}.
#'
#' @examples
#' \dontrun{
#' render_replication("10.1177/00491241211036161", "fig_1")
#' render_replication("10.1017/S0003055403000534", "tab_1", language = "stata")
#' }
#'
#' @keywords internal
render_replication <- function(
  doi,
  what,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  skip_prep = FALSE,
  force = FALSE,
  meta = NULL,
  ctx = NULL,
  engines = NULL
) {
  doi <- prepare_doi_for_replication(doi)
  if (is.null(meta)) {
    meta <- get_replication_meta(doi, repo = repo, folder = folder)
  }
  assert_study_ready_for_replication(
    doi,
    meta = meta,
    repo = repo,
    folder = folder,
    install_deps = install_deps,
    engines = engines
  )
  if (is.null(ctx)) {
    ctx <- paper_context(doi, repo = repo, folder = folder)
  }

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    pkg_meta <- tryCatch(
      read_package_replication_meta(pkg),
      error = function(e) meta
    )
    obj <- run_package_replication(
      pkg,
      what,
      meta = pkg_meta,
      install_deps = install_deps
    )
    entries <- package_yaml_entries(pkg_meta)
    if (length(entries) == 0L) {
      entries <- package_yaml_entries(meta)
    }
    rep_matches <- entries[vapply(entries, function(x) identical(x$id, what), logical(1))]
    rep <- if (length(rep_matches) > 0) {
      rep_matches[[1]]
    } else {
      list(id = what, type = "unknown", description = "Package-backed replication")
    }
    has_fmt <- !is.null(rep$format) && nzchar(as.character(rep$format[[1]] %||% ""))
    return(structure(
      list(
        id = what,
        type = rep$type %||% "unknown",
        object = obj,
        format = infer_result_format(obj, rep$type %||% "unknown"),
        has_format = has_fmt,
        meta = rep,
        source = "package"
      ),
      class = "replication_result"
    ))
  }

  rep <- find_replication_entry(meta, what, language = language)

  if (is_prep_entry(rep)) {
  run_ctx <- step_code_context(rep, meta, ctx)
  study_root <- step_study_root(rep, meta, ctx)
    if (!isTRUE(force) && step_outputs_ready(rep, run_ctx, meta = meta)) {
      out_path <- step_primary_output_path(rep, run_ctx, meta = meta)
      return(structure(
        list(
          id = what,
          entry_id = rep$id,
          language = replication_engine(rep, meta$paper),
          type = rep$type %||% "step",
          object = preview_data_file(out_path),
          output_path = out_path,
          status = paste0("Using existing output: ", basename(out_path)),
          format = "data.frame",
          has_format = FALSE,
          meta = rep,
          source = "prep"
        ),
        class = "replication_result"
      ))
    }
    out_path <- prep_output_path(rep, run_ctx, meta = meta)
    if (!isTRUE(force) && !is.null(out_path) && file.exists(out_path)) {
      return(structure(
        list(
          id = what,
          entry_id = rep$id,
          language = replication_engine(rep, meta$paper),
          type = rep$type %||% "step",
          object = preview_data_file(out_path),
          output_path = out_path,
          status = paste0("Using existing output: ", basename(out_path)),
          format = "data.frame",
          has_format = FALSE,
          meta = rep,
          source = "prep"
        ),
        class = "replication_result"
      ))
    }
    status_msg <- NULL
    if (is_stata_replication(rep, meta$paper)) {
      ensure_stata_available(rep)
      run_stata_replication(rep, run_ctx, meta = meta, install_deps = install_deps)
      status_msg <- "Stata pipeline step finished."
    } else if (is_python_replication(rep, meta$paper)) {
      ensure_python_available(rep)
      run_python_replication(rep, run_ctx, meta = meta, install_deps = install_deps)
      status_msg <- "Python pipeline step finished."
    } else {
      ensure_replication_dependencies(
        rep,
        paper_meta = meta$paper,
        install_missing = allow_dependency_install(install_deps)
      )
      with_replicate_study_root(study_root, {
        env <- new.env(parent = globalenv())
        source_replication_scripts(rep, run_ctx, env, install_deps = install_deps, include_format = FALSE, meta = meta)
        fn <- get_analysis_function(env, what, rep$type %||% "step")
        data_paths <- replication_data_paths(rep)
        if (length(data_paths) > 0L) {
          data <- load_replication_data(data_paths, run_ctx, meta = meta)
          retry_with_missing_package(fn(data), install_missing = allow_dependency_install(install_deps))
        } else {
          retry_with_missing_package(fn(), install_missing = allow_dependency_install(install_deps))
        }
      })
      status_msg <- "Pipeline step finished."
    }
    out_path <- prep_output_path(rep, run_ctx, meta = meta)
    preview <- if (!is.null(out_path) && file.exists(out_path)) {
      preview_data_file(out_path)
    } else {
      list(id = what, note = "Prep step completed (no preview available).")
    }
    return(structure(
      list(
        id = what,
        entry_id = rep$id,
        language = replication_engine(rep, meta$paper),
        type = rep$type %||% "step",
        object = preview,
        output_path = out_path,
        status = status_msg,
        format = "data.frame",
        has_format = FALSE,
        meta = rep,
        source = "prep"
      ),
      class = "replication_result"
    ))
  }

  if (!isTRUE(skip_prep)) {
    steps <- normalize_study_steps(meta)
    if (length(steps) > 0L && !is_prep_entry(rep)) {
      ensure_study_ancestor_steps(
        meta,
        rep,
        ctx,
        doi = doi,
        install_deps = install_deps,
        repo = repo,
        folder = folder
      )
    } else {
      ensure_prep_dependencies(
        meta,
        rep,
        ctx,
        doi = doi,
        install_deps = install_deps
      )
    }
  }

  run_ctx <- step_code_context(rep, meta, ctx)

  if (is_stata_replication(rep, meta$paper)) {
    ensure_stata_available(rep)
    obj <- run_stata_replication(rep, run_ctx, meta = meta, install_deps = install_deps)
    return(structure(
      list(
        id = what,
        entry_id = rep$id,
        language = replication_engine(rep, meta$paper),
        type = rep$type,
        object = obj,
        format = infer_result_format(obj, rep$type),
        has_format = format_specified(rep),
        meta = rep,
        source = "stata"
      ),
      class = "replication_result"
    ))
  }

  if (is_python_replication(rep, meta$paper)) {
    ensure_python_available(rep)
    obj <- run_python_replication(rep, run_ctx, meta = meta, install_deps = install_deps)
    obj_type <- rep$type %||% "figure"
    return(structure(
      list(
        id = what,
        entry_id = rep$id,
        language = "python",
        type = obj_type,
        object = obj,
        format = infer_result_format(obj, obj_type),
        has_format = format_specified(rep),
        meta = rep,
        source = "python"
      ),
      class = "replication_result"
    ))
  }

  ensure_replication_dependencies(
    rep,
    paper_meta = meta$paper,
    install_missing = allow_dependency_install(install_deps)
  )

  data_paths <- replication_data_paths(rep)
  data <- load_replication_data(
    if (length(data_paths) > 0L) data_paths else NULL,
    run_ctx,
    meta = meta
  )

  study_root <- step_study_root(rep, meta, ctx)
  env <- new.env(parent = globalenv())
  result <- with_replicate_study_root(study_root, {
    source_replication_scripts(rep, run_ctx, env, install_deps = install_deps, include_format = FALSE, meta = meta)
    analysis_fn <- get_analysis_function(env, what, rep$type)
    retry_with_missing_package(
      analysis_fn(data),
      install_missing = allow_dependency_install(install_deps)
    )
  })

  structure(
    list(
      id = what,
      entry_id = rep$id,
      language = replication_engine(rep, meta$paper),
      type = rep$type,
      object = result,
      format = infer_result_format(result, rep$type),
      has_format = format_specified(rep),
      meta = rep,
      source = "r"
    ),
    class = "replication_result"
  )
}

#' Get artifact URL or local path for a replication
#'
#' @param doi Character. DOI of the paper.
#' @param what Replication identifier.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return Character path or URL, or \code{NULL} if no artifact is registered.
#'
#' @examples
#' \dontrun{
#' get_artifact_path("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
get_artifact_path <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  rep <- tryCatch(
    find_replication_entry(meta, what, language = NULL),
    error = function(e) NULL
  )

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    tryCatch(
      prepare_package_replication(pkg, meta, ctx),
      error = function(e) NULL
    )
    if (replication_package_usable(pkg)) {
      path <- tryCatch(
        call_replication_package(pkg, "artifact_file", what),
        error = function(e) NULL
      )
      if (!is.null(path) && nzchar(path) && file.exists(path)) {
        return(path)
      }
    }
    return(package_installed_artifact_path(what, pkg, meta = meta, ctx = ctx))
  }

  if (is.null(rep)) {
    return(resolve_registry_artifact_path(what, ctx, rep = NULL, doi = doi))
  }
  for (rel in study_artifact_rel_candidates(rep)) {
    if (!is.null(ctx$local_root)) {
      local <- file.path(ctx$local_root, rel)
      if (file.exists(local)) {
        return(normalizePath(local, winslash = "/", mustWork = FALSE))
      }
    }
  }
  resolve_registry_artifact_path(rep$id, ctx, rep, doi = doi)
}

#' Load a precomputed artifact for a replication
#'
#' @inheritParams render_replication
#' @return Artifact contents suitable for display, or \code{NULL}.
#'
#' @examples
#' \dontrun{
#' load_artifact("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
load_artifact <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  rep <- tryCatch(
    find_replication_entry(meta, what, language = NULL),
    error = function(e) NULL
  )

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    tryCatch(
      prepare_package_replication(pkg, meta, ctx),
      error = function(e) NULL
    )
    if (replication_package_usable(pkg)) {
      result <- tryCatch(
        call_replication_package(pkg, "load_artifact", what),
        error = function(e) NULL
      )
      if (!artifact_content_missing(result)) {
        return(result)
      }
    }
    path <- package_installed_artifact_path(what, pkg, meta = meta, ctx = ctx)
    if (!is.null(path)) {
      return(load_artifact_file_path(path))
    }
    return(NULL)
  }

  if (!is.null(rep) && is_prep_entry(rep)) {
    prep_display <- load_prep_step_display(meta, ctx, rep)
    if (!artifact_content_missing(prep_display)) {
      return(resolve_prep_display_object(prep_display))
    }
  }

  path <- get_artifact_path(doi, what, repo = repo, folder = folder, language = language)
  if (!is.null(path)) {
    loaded <- load_artifact_file_path(path)
    if (!artifact_content_missing(loaded)) {
      return(loaded)
    }
  }
  if (!is.null(rep)) {
    for (rel in study_artifact_rel_candidates(rep)) {
      candidate <- NULL
      if (!is.null(ctx$local_root)) {
        local <- file.path(ctx$local_root, rel)
        if (file.exists(local)) {
          candidate <- local
        }
      }
      if (is.null(candidate)) {
        candidate <- registry_url(ctx$base_url, rel)
      }
      loaded <- load_artifact_file_path(candidate)
      if (!artifact_content_missing(loaded)) {
        return(loaded)
      }
    }
  }
  NULL
}

#' Human-readable list of artifact URLs/paths tried for a replication
#'
#' @inheritParams get_artifact_path
#' @keywords internal
artifact_lookup_candidates <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    paths <- character(0)
    tryCatch(
      prepare_package_replication(pkg, meta, ctx),
      error = function(e) NULL
    )
    if (replication_package_usable(pkg)) {
      path <- tryCatch(
        call_replication_package(pkg, "artifact_file", what),
        error = function(e) NULL
      )
      if (!is.null(path) && nzchar(path)) {
        paths <- c(paths, path)
      }
    }
    installed <- package_installed_artifact_path(what, pkg, meta = meta, ctx = ctx)
    if (!is.null(installed)) {
      paths <- c(paths, installed)
    }
    return(unique(paths[nzchar(paths)]))
  }

  rep <- tryCatch(
    find_replication_entry(meta, what, language = NULL),
    error = function(e) NULL
  )
  if (is.null(rep)) {
    return(character(0))
  }
  paths <- character(0)
  for (rel in study_artifact_rel_candidates(rep)) {
    if (!is.null(ctx$local_root)) {
      local <- file.path(ctx$local_root, rel)
      if (file.exists(local)) {
        paths <- c(paths, normalizePath(local, winslash = "/", mustWork = FALSE))
      }
    }
    paths <- c(paths, registry_url(ctx$base_url, rel))
  }
  unique(paths[nzchar(paths)])
}

#' @keywords internal
read_artifact_file <- function(path, ext) {
  switch(
    ext,
    html = normalize_html_table(paste(readLines(path, warn = FALSE), collapse = "\n")),
    png = path,
    svg = path,
    rds = preview_data_file(path),
    csv = preview_data_file(path),
    dta = preview_data_file(path),
    paste(readLines(path, warn = FALSE), collapse = "\n")
  )
}

#' Save a replication result as an artifact file
#'
#' @param result A replication result envelope from \code{render_replication()}.
#' @param output_dir Directory in which to write the artifact.
#' @param doi Optional DOI; required to apply a registered \code{format_*} step.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name.
#' @param install_deps Logical; passed to \code{format_for_display()}.
#'
#' @importFrom grDevices dev.off png
#'
#' @return Invisibly the output file path.
#'
#' @examples
#' \dontrun{
#' tmp <- tempfile()
#' dir.create(tmp)
#' result <- structure(
#'   list(
#'     id = "tab_1",
#'     type = "table",
#'     object = data.frame(x = 1:2, y = 3:4),
#'     format = "data.frame",
#'     meta = list(id = "tab_1")
#'   ),
#'   class = "replication_result"
#' )
#' save_artifact(result, tmp)
#' }
#'
#' @keywords internal
save_artifact <- function(
  result,
  output_dir,
  doi = NULL,
  repo = NULL,
  folder = NULL,
  install_deps = FALSE
) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  rep <- result$meta %||% list()
  object <- replication_object(result)
  format_type <- infer_result_format(object, result$type %||% rep$type %||% "unknown")

  if (format_specified(rep)) {
    if (is.null(doi) || !nzchar(doi)) {
      stop("doi is required to save display artifacts when format is specified.", call. = FALSE)
    }
    object <- format_for_display(
      object,
      doi,
      result$id,
      install_deps = install_deps,
      repo = repo,
      folder = folder
    )
    format_type <- infer_result_format(object, result$type %||% rep$type %||% "unknown")
  }

  natural_ext <- switch(
    format_type,
    ggplot = "png",
    html = "html",
    `data.frame` = "html",
    plot = "png",
    png = "png",
    stata_output = "smcl",
    "rds"
  )

  # Single source of truth for the artifact location: study_artifact_rel_path()
  # (first displayable outputs: path in replication.yml, or the type-based
  # default). Builds write exactly where lookup reads. The filename and
  # extension come from that rule; a mismatch with what the result actually
  # serializes to is a study configuration error and is reported here rather
  # than silently written to a path lookup will never check.
  rel <- study_artifact_rel_path(rep)
  declared_ext <- tolower(tools::file_ext(rel))
  if (nzchar(declared_ext) && !identical(declared_ext, natural_ext)) {
    stop(
      "outputs: for ", result$id, " declares a .", declared_ext,
      " file but the result serializes as .", natural_ext,
      ". Fix the outputs: extension in replication.yml.",
      call. = FALSE
    )
  }
  ext <- if (nzchar(declared_ext)) declared_ext else natural_ext
  out_path <- file.path(output_dir, basename(rel))

  if (format_type == "ggplot") {
    if (!requireNamespace("ggplot2", quietly = TRUE)) {
      stop("Saving ggplot artifacts requires the 'ggplot2' package.")
    }
    ggplot2::ggsave(out_path, plot = object, width = 8, height = 6, dpi = 150)
  } else if (format_type == "html") {
    html <- if (inherits(object, "html")) {
      as.character(object)
    } else {
      as.character(object)
    }
    html <- normalize_html_table(html)
    writeLines(html, out_path, useBytes = TRUE)
  } else if (format_type == "data.frame") {
    if (!is.data.frame(object) && !is.matrix(object)) {
      stop(
        "Cannot save ", result$id, " as a table artifact: expected a data frame, got ",
        paste(class(object), collapse = "/"),
        call. = FALSE
      )
    }
    html <- paste0(
      "<table class=\"table table-striped table-bordered\">",
      .df_to_html(object),
      "</table>"
    )
    writeLines(html, out_path, useBytes = TRUE)
  } else if (format_type == "stata_output" && inherits(object, "stata_replication_result")) {
    src <- object$output_path %||% object$smcl_path
    file.copy(src, out_path, overwrite = TRUE)
  } else if (format_type == "png" && is.character(object) && length(object) == 1L && file.exists(object)) {
    src <- normalizePath(object, winslash = "/", mustWork = FALSE)
    dest <- normalizePath(out_path, winslash = "/", mustWork = FALSE)
    if (!identical(src, dest)) {
      file.copy(object, out_path, overwrite = TRUE)
    }
  } else if (format_type == "plot" && !is.null(object)) {
    png(out_path, width = 800, height = 600)
    on.exit(dev.off(), add = TRUE)
    print(object)
  } else {
    saveRDS(object, out_path)
  }

  invisible(out_path)
}

#' @keywords internal
.df_to_html <- function(df) {
  headers <- paste0("<th>", colnames(df), "</th>", collapse = "")
  rows <- apply(df, 1, function(row) {
    paste0("<tr>", paste0("<td>", row, "</td>", collapse = ""), "</tr>")
  })
  paste0("<thead><tr>", headers, "</tr></thead><tbody>", paste(rows, collapse = ""), "</tbody>")
}

#' @keywords internal
`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
}

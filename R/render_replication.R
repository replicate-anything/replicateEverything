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
      get("replication_meta", envir = asNamespace(pkg))(),
      error = function(e) NULL
    )
    if (!is.null(pkg_meta)) {
      meta$replications <- pkg_meta$replications %||% list()
      if (length(meta$prep %||% list()) == 0) {
        meta$prep <- pkg_meta$prep %||% list()
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
      "https://raw.githubusercontent.com/%s/main/papers/%s/replication.yml",
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
  enrich_folder_study_replication_meta(meta, ctx)
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

#' @keywords internal
.artifact_path_cache <- new.env(parent = emptyenv())

#' Relative artifact paths to try under registry \code{papers/<folder>/}
#'
#' @param what Replication id.
#' @param rep Optional replication entry.
#' @param ctx Optional paper context (for `manifest.json`).
#' @keywords internal
registry_artifact_rel_paths <- function(what, rep = NULL, ctx = NULL) {
  paths <- character(0)
  if (!is.null(ctx)) {
    paths <- c(paths, manifest_artifact_paths(what, ctx))
  }
  if (!is.null(rep) && !is.null(rep$artifact) && nzchar(rep$artifact)) {
    art <- as.character(rep$artifact)
    paths <- c(
      paths,
      art,
      sub("^inst/report/", "", art),
      sub("^inst/", "", art)
    )
  }
  for (ext in c("html", "png", "rds", "svg")) {
    paths <- c(paths, paste0("artifacts/", what, ".", ext))
  }
  unique(paths[nzchar(paths)])
}

#' Artifact paths recorded in \code{artifacts/manifest.json}
#'
#' @param what Replication id.
#' @param ctx Paper context.
#' @keywords internal
manifest_artifact_paths <- function(what, ctx) {
  read_manifest <- function(manifest) {
    if (is.null(manifest) || is.null(manifest$replications)) {
      return(character(0))
    }
    reps <- manifest$replications
    entry <- reps[[what]] %||% NULL
    if (is.null(entry) || is.null(entry$artifact) || !nzchar(entry$artifact)) {
      return(character(0))
    }
    as.character(entry$artifact)
  }

  paths <- character(0)
  if (!is.null(ctx$local_root)) {
    local_manifest <- file.path(ctx$local_root, "artifacts", "manifest.json")
    if (file.exists(local_manifest)) {
      manifest <- tryCatch(
        jsonlite::fromJSON(local_manifest, simplifyVector = FALSE),
        error = function(e) NULL
      )
      paths <- c(paths, read_manifest(manifest))
    }
  }

  manifest_url <- paste0(ctx$base_url, "/artifacts/manifest.json")
  resp <- tryCatch(
    httr::GET(
      manifest_url,
      httr::user_agent("replicateEverything"),
      httr::timeout(15)
    ),
    error = function(e) NULL
  )
  if (!is.null(resp) && httr::status_code(resp) < 400L) {
    manifest <- tryCatch(
      jsonlite::fromJSON(
        httr::content(resp, as = "text", encoding = "UTF-8"),
        simplifyVector = FALSE
      ),
      error = function(e) NULL
    )
    paths <- c(paths, read_manifest(manifest))
  }

  unique(paths[nzchar(paths)])
}

#' @keywords internal
url_exists <- function(url) {
  resp <- tryCatch(
    httr::HEAD(
      url,
      httr::user_agent("replicateEverything"),
      httr::timeout(10)
    ),
    error = function(e) NULL
  )
  !is.null(resp) && httr::status_code(resp) < 400L
}

#' Resolve a precomputed artifact under the registry paper folder
#'
#' Package-backed studies may ship display artifacts in \code{inst/report/artifacts/}
#' on the study package (not under the registry paper folder).
#'
#' @param what Replication id.
#' @param ctx Paper context.
#' @param rep Optional replication entry.
#' @param doi Optional DOI for caching.
#' @keywords internal
resolve_registry_artifact_path <- function(what, ctx, rep = NULL, doi = NULL) {
  cache_key <- paste(doi %||% ctx$folder %||% "", what, sep = "|")
  if (exists(cache_key, envir = .artifact_path_cache, inherits = FALSE)) {
    cached <- get(cache_key, envir = .artifact_path_cache)
    return(if (is.na(cached)) NULL else cached)
  }

  result <- NULL
  rel_paths <- registry_artifact_rel_paths(what, rep, ctx)
  for (rel in rel_paths) {
    if (!is.null(ctx$local_root)) {
      local <- file.path(ctx$local_root, rel)
      if (file.exists(local)) {
        result <- local
        break
      }
    }
  }
  if (is.null(result)) {
    for (rel in rel_paths) {
      url <- paste0(ctx$base_url, "/", rel)
      if (url_exists(url)) {
        result <- url
        break
      }
    }
  }

  assign(cache_key, result %||% NA_character_, envir = .artifact_path_cache)
  result
}

#' @keywords internal
package_installed_artifact_path <- function(what, pkg, meta = NULL, ctx = NULL) {
  if (!is.null(meta) && !is.null(ctx)) {
    local_root <- resolve_replication_package_path(pkg, meta, ctx)
    if (!is.null(local_root)) {
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
  for (ext in c("png", "html", "rds", "svg")) {
    path <- system.file(
      "report", "artifacts", paste0(what, ".", ext),
      package = pkg
    )
    if (nzchar(path) && file.exists(path)) {
      return(path)
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
    get("replication_meta", envir = asNamespace(pkg))(),
    error = function(e) NULL
  )
  if (is.null(pkg_meta)) {
    return(list())
  }
  c(pkg_meta$prep %||% list(), pkg_meta$replications %||% list())
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
  folder = NULL
) {
  doi <- prepare_doi_for_replication(doi)
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    obj <- call_replication_package(pkg, "run_replication", what, install_deps = install_deps)
    entries <- c(meta$prep %||% list(), meta$replications %||% list())
    rep_matches <- entries[vapply(entries, function(x) identical(x$id, what), logical(1))]
    rep <- if (length(rep_matches) > 0) {
      rep_matches[[1]]
    } else {
      list(id = what, type = "unknown", description = "Package-backed replication")
    }
    return(structure(
      list(
        id = what,
        type = rep$type %||% "unknown",
        object = obj,
        format = infer_result_format(obj, rep$type %||% "unknown"),
        has_format = TRUE,
        meta = rep,
        source = "package"
      ),
      class = "replication_result"
    ))
  }

  rep <- find_replication_entry(meta, what, language = language)

  if (is_stata_replication(rep, meta$paper)) {
    ensure_stata_available(rep)
    obj <- run_stata_replication(rep, ctx, meta = meta)
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

  ensure_replication_dependencies(
    rep,
    paper_meta = meta$paper,
    install_missing = install_deps
  )

  data <- load_replication_data(rep$data, ctx, meta = meta)

  env <- new.env(parent = globalenv())
  source_replication_scripts(rep, ctx, env, install_deps = install_deps, include_format = FALSE, meta = meta)

  analysis_fn <- get_analysis_function(env, what, rep$type)
  result <- retry_with_missing_package(
    analysis_fn(data),
    install_missing = install_deps
  )

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
    find_replication_entry(meta, what, language = language),
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
    return(NULL)
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
    find_replication_entry(meta, what, language = language),
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

  path <- get_artifact_path(doi, what, repo = repo, folder = folder, language = language)
  if (is.null(path)) {
    return(NULL)
  }
  load_artifact_file_path(path)
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
    find_replication_entry(meta, what, language = language),
    error = function(e) NULL
  )
  rel <- registry_artifact_rel_paths(if (is.null(rep)) what else rep$id, rep, ctx)
  vapply(rel, function(r) {
    if (!is.null(ctx$local_root)) {
      local <- file.path(ctx$local_root, r)
      if (file.exists(local)) {
        return(local)
      }
    }
    paste0(ctx$base_url, "/", r)
  }, character(1))
}

#' @keywords internal
read_artifact_file <- function(path, ext) {
  switch(
    ext,
    html = normalize_html_table(paste(readLines(path, warn = FALSE), collapse = "\n")),
    png = path,
    svg = path,
    rds = readRDS(path),
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
  format_type <- result$format

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
    format_type <- infer_result_format(object, result$type)
  }

  ext <- switch(
    format_type,
    ggplot = "png",
    html = "html",
    `data.frame` = "html",
    plot = "png",
    png = "png",
    stata_output = "smcl",
    "rds"
  )

  out_path <- file.path(output_dir, paste0(result$id, ".", ext))

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
    file.copy(object, out_path, overwrite = TRUE)
  } else if (format_type == "plot" && !is.null(object)) {
    png(out_path, width = 800, height = 600)
    on.exit(dev.off(), add = TRUE)
    print(object)
  } else {
    saveRDS(object, out_path)
    ext <- "rds"
    out_path <- file.path(output_dir, paste0(result$id, ".", ext))
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
  if (is.null(a)) b else a
}

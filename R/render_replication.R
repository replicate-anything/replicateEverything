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

  pkg <- as.character(meta$paper$package[[1]])
  tryCatch({
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    pkg_meta <- get("replication_meta", envir = asNamespace(pkg))()
    meta$replications <- pkg_meta$replications %||% list()
    if (length(meta$prep %||% list()) == 0) {
      meta$prep <- pkg_meta$prep %||% list()
    }
  }, error = function(e) meta)
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
  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (!is.null(ctx$local_root)) {
    local_yml <- file.path(ctx$local_root, "replication.yml")
    if (file.exists(local_yml)) {
      return(enrich_package_replication_meta(yaml::read_yaml(local_yml), ctx))
    }
  }

  urls <- unique(c(
    paste0(ctx$base_url, "/replication.yml"),
    paste0("https://raw.githubusercontent.com/", ctx$repo, "/main/replication.yml"),
    paste0("https://raw.githubusercontent.com/", ctx$repo, "/main/inst/replication.yml")
  ))

  for (meta_url in urls) {
    meta <- tryCatch({
      tmp <- download_registry_file(meta_url)
      on.exit(unlink(tmp), add = TRUE)
      yaml::read_yaml(tmp)
    }, error = function(e) NULL)
    if (!is.null(meta)) {
      return(enrich_package_replication_meta(meta, ctx))
    }
  }

  stop("Could not load replication.yml for ", doi, call. = FALSE)
}

get_replication_meta <- function(doi, repo = NULL, folder = NULL) {
  get_replication_meta_impl(doi, repo = repo, folder = folder)
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

#' Find a single replication entry by id
#'
#' @param meta Parsed replication metadata.
#' @param what Replication identifier.
#'
#' @keywords internal
find_replication_entry <- function(meta, what) {
  entries <- meta$replications %||% list()
  matches <- entries[
    vapply(entries, function(x) identical(x$id, what), logical(1))
  ]

  if (length(matches) == 0 && is_package_replication(meta)) {
    entries <- package_replication_entries(meta)
    matches <- entries[
      vapply(entries, function(x) identical(x$id, what), logical(1))
    ]
  }

  if (length(matches) == 0) {
    stop("Replication ", what, " not found in metadata")
  }

  matches[[1]]
}

#' Render a single replication
#'
#' Loads data, sources the replication script, and returns a typed result
#' envelope suitable for Shiny display or artifact generation.
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (e.g., \code{"fig_1"}).
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return A list with \code{id}, \code{type}, \code{object}, and \code{format}.
#' @export
render_replication <- function(doi, what, install_deps = FALSE, repo = NULL, folder = NULL) {
  doi <- normalize_doi(doi)
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

  rep <- find_replication_entry(meta, what)

  ensure_replication_dependencies(
    rep,
    paper_meta = meta$paper,
    install_missing = install_deps
  )

  data <- load_replication_data(rep$data, ctx)

  env <- new.env(parent = globalenv())
  source_replication_scripts(rep, ctx, env, install_deps = install_deps, include_format = FALSE)

  analysis_fn <- get_analysis_function(env, what, rep$type)
  result <- retry_with_missing_package(
    analysis_fn(data),
    install_missing = install_deps
  )

  structure(
    list(
      id = what,
      type = rep$type,
      object = result,
      format = infer_result_format(result, rep$type),
      has_format = format_specified(rep),
      meta = rep
    ),
    class = "replication_result"
  )
}

#' @keywords internal
download_registry_file <- function(url) {
  ext <- tools::file_ext(sub(".*\\.", "", basename(url)))
  if (!nzchar(ext)) {
    ext <- "txt"
  }
  tmp <- tempfile(fileext = paste0(".", ext))
  utils::download.file(url, tmp, quiet = TRUE, mode = "wb")
  tmp
}

#' Get artifact URL or local path for a replication
#'
#' @param doi Character. DOI of the paper.
#' @param what Replication identifier.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return Character path or URL, or \code{NULL} if no artifact is registered.
#' @export
get_artifact_path <- function(doi, what, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    ctx <- paper_context(doi, repo = repo, folder = folder)
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    for (ext in c("png", "html", "rds")) {
      path <- system.file(
        "report", "artifacts", paste0(what, ".", ext),
        package = pkg
      )
      if (nzchar(path) && file.exists(path)) {
        return(path)
      }
    }
    return(NULL)
  }

  rep <- find_replication_entry(meta, what)
  artifact <- rep$artifact
  if (is.null(artifact) || !nzchar(artifact)) {
    artifact <- default_artifact_path(rep, what)
  }

  if (is.null(artifact) || !nzchar(artifact)) {
    return(NULL)
  }

  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (!is.null(ctx$local_root)) {
    local_artifact <- file.path(ctx$local_root, artifact)
    if (file.exists(local_artifact)) {
      return(local_artifact)
    }
  }

  paste0(ctx$base_url, "/", artifact)
}

#' Load a precomputed artifact for a replication
#'
#' @inheritParams render_replication
#' @return Artifact contents suitable for display, or \code{NULL}.
#' @export
load_artifact <- function(doi, what, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    ctx <- paper_context(doi, repo = repo, folder = folder)
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    return(call_replication_package(pkg, "load_artifact", what))
  }

  path <- get_artifact_path(doi, what, repo = repo, folder = folder)
  if (is.null(path)) {
    return(NULL)
  }

  if (grepl("^https?://", path)) {
    ext <- tolower(tools::file_ext(path))
    tmp <- tempfile(fileext = paste0(".", ext))
    ok <- tryCatch({
      utils::download.file(path, tmp, quiet = TRUE, mode = "wb")
      file.exists(tmp) && file.info(tmp)$size > 0
    }, error = function(e) FALSE)
    if (!ok) {
      return(NULL)
    }
    if (ext %in% c("png", "svg", "jpg", "jpeg")) {
      dest <- tempfile(fileext = paste0(".", ext))
      file.copy(tmp, dest, overwrite = TRUE)
      unlink(tmp)
      return(dest)
    }
    on.exit(unlink(tmp), add = TRUE)
    return(read_artifact_file(tmp, ext))
  }

  read_artifact_file(path, tolower(tools::file_ext(path)))
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
#'
#' @return Invisibly the output file path.
#' @export
save_artifact <- function(result, output_dir) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  object <- replication_object(result)
  save_analysis <- format_specified(result$meta %||% list())

  ext <- if (save_analysis) {
    "rds"
  } else {
    switch(
      result$format,
      ggplot = "png",
      html = "html",
      `data.frame` = "html",
      plot = "png",
      "rds"
    )
  }

  out_path <- file.path(output_dir, paste0(result$id, ".", ext))

  if (save_analysis) {
    saveRDS(object, out_path)
  } else if (result$format == "ggplot") {
    if (!requireNamespace("ggplot2", quietly = TRUE)) {
      stop("Saving ggplot artifacts requires the 'ggplot2' package.")
    }
    ggplot2::ggsave(out_path, plot = object, width = 8, height = 6, dpi = 150)
  } else if (result$format == "html") {
    html <- if (inherits(object, "html")) {
      as.character(object)
    } else {
      as.character(object)
    }
    html <- normalize_html_table(html)
    writeLines(html, out_path, useBytes = TRUE)
  } else if (result$format == "data.frame") {
    html <- paste0(
      "<table class=\"table table-striped table-bordered\">",
      .df_to_html(object),
      "</table>"
    )
    writeLines(html, out_path, useBytes = TRUE)
  } else if (result$format == "plot" && !is.null(object)) {
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

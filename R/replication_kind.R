#' Classify a registry study by materials layout
#'
#' @param meta Parsed replication metadata (registry stub or full yaml).
#' @param ctx Optional paper context from [paper_context()].
#' @return \code{"package"}, \code{"folder"}, or \code{"registry"}.
#' @keywords internal
replication_kind <- function(meta, ctx = NULL) {
  if (is.null(meta)) {
    return("registry")
  }
  if (isTRUE(is_package_replication(meta))) {
    return("package")
  }
  if (is_folder_study_replication(meta, ctx)) {
    return("folder")
  }
  "registry"
}

#' Materialize study materials for maintainer probes and installs
#'
#' Folder studies are cloned/cached locally; package studies are loaded or
#' installed from GitHub.
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @return List with \code{kind}, \code{root}, \code{meta}, and optional
#'   \code{package}.
#' @keywords internal
materialize_study <- function(meta, ctx) {
  kind <- replication_kind(meta, ctx)
  if (identical(kind, "package")) {
    pkg <- as.character(meta$paper$package[[1]] %||% "")
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    root <- package_source_root(pkg)
    full_meta <- tryCatch(
      read_package_replication_meta(pkg),
      error = function(e) meta
    )
    return(list(
      kind = kind,
      root = root,
      meta = full_meta,
      package = pkg
    ))
  }
  if (identical(kind, "folder")) {
    root <- ensure_study_folder_local(meta, ctx)
    full_meta <- complete_folder_study_meta(meta, root)
    return(list(
      kind = kind,
      root = root,
      meta = full_meta,
      package = NULL
    ))
  }
  list(kind = kind, root = NULL, meta = meta, package = NULL)
}

#' Display output directory for a study
#'
#' Folder-backed studies use \code{outputs/}. Package-backed studies use
#' \code{inst/report/outputs/}.
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @param installed When \code{TRUE}, prefer the installed package path.
#' @param package Optional package name (package-backed studies).
#' @return Normalized directory path or \code{NULL}.
#' @keywords internal
study_output_dir <- function(
  meta,
  ctx = NULL,
  installed = TRUE,
  package = NULL
) {
  kind <- replication_kind(meta, ctx)
  if (identical(kind, "package")) {
    pkg <- package %||% as.character(meta$paper$package[[1]] %||% "")
    if (!nzchar(pkg)) {
      return(NULL)
    }
    if (isTRUE(installed) && replication_package_usable(pkg)) {
      for (parts in list(
        c("report", "outputs"),
        c("report", "artifacts")
      )) {
        path <- system.file(parts, package = pkg)
        if (nzchar(path)) {
          return(normalizePath(path, winslash = "/", mustWork = FALSE))
        }
      }
    }
    root <- package_source_root(pkg)
    if (!is.null(root)) {
      for (subdir in c("outputs", "artifacts")) {
        candidate <- file.path(root, "inst", "report", subdir)
        if (dir.exists(candidate)) {
          return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
        }
      }
      return(normalizePath(
        file.path(root, "inst", "report", "outputs"),
        winslash = "/",
        mustWork = FALSE
      ))
    }
    return(NULL)
  }
  if (identical(kind, "folder")) {
    root <- resolve_study_folder_path(meta, ctx)
    if (
      (is.null(root) || !nzchar(root) || !dir.exists(root)) &&
      !is.null(ctx) &&
      !is.null(ctx$local_root) &&
      dir.exists(ctx$local_root) &&
      file.exists(file.path(ctx$local_root, "replication.yml"))
    ) {
      root <- ctx$local_root
    }
    if (is.null(root) || !dir.exists(root)) {
      return(NULL)
    }
    normalizePath(
      file.path(root, "outputs"),
      winslash = "/",
      mustWork = FALSE
    )
  }
  NULL
}

#' @rdname study_output_dir
#' @keywords internal
study_artifact_dir <- function(
  meta,
  ctx = NULL,
  installed = TRUE,
  package = NULL
) {
  study_output_dir(meta, ctx = ctx, installed = installed, package = package)
}

#' Manifest path for a study's precomputed display outputs
#'
#' @inheritParams study_artifact_dir
#' @return Character path or \code{NULL}.
#' @keywords internal
study_manifest_path <- function(meta, ctx = NULL, installed = TRUE, package = NULL) {
  art_dir <- study_artifact_dir(meta, ctx, installed = installed, package = package)
  if (is.null(art_dir) || !nzchar(art_dir)) {
    return(NULL)
  }
  kind <- replication_kind(meta, ctx)
  if (identical(kind, "package")) {
    return(file.path(dirname(art_dir), "manifest.json"))
  }
  file.path(art_dir, "manifest.json")
}

#' Maintainer build function name for a study kind
#'
#' @param kind Output of [replication_kind()].
#' @return \code{"build_study_outputs"}.
#' @keywords internal
study_build_function <- function(kind) {
  "build_study_outputs"
}

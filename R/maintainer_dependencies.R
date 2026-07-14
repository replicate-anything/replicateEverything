#' Enable maintainer-only dependency installation for a code block
#'
#' Sets \code{replicateEverything.install_dependencies} and
#' \code{replicateEverything.install_stata_deps} to \code{TRUE}, then restores
#' previous values on exit.
#'
#' @param code Expression to evaluate.
#' @return Value of \code{code}.
#' @keywords internal
with_maintainer_install_opts <- function(code) {
  old <- options(
    replicateEverything.install_dependencies = TRUE,
    replicateEverything.install_stata_deps = TRUE
  )
  on.exit(
    options(
      replicateEverything.install_dependencies = old[[
        "replicateEverything.install_dependencies"
      ]],
      replicateEverything.install_stata_deps = old[[
        "replicateEverything.install_stata_deps"
      ]]
    ),
    add = TRUE
  )
  force(code)
}

#' Install CRAN packages declared for a study
#' @keywords internal
install_study_r_packages <- function(meta) {
  pkgs <- study_declared_r_packages(meta)
  pkgs <- unique(pkgs[nzchar(pkgs)])
  if (length(pkgs) == 0L) {
    return(invisible(TRUE))
  }
  missing <- pkgs[
    !vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) == 0L) {
    message("R packages already satisfied: ", paste(pkgs, collapse = ", "))
    return(invisible(TRUE))
  }
  old_repos <- getOption("repos")
  on.exit(options(repos = old_repos), add = TRUE)
  if (is.null(old_repos) || identical(old_repos[["CRAN"]], "@CRAN@")) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }
  message("Installing R packages: ", paste(missing, collapse = ", "))
  utils::install.packages(missing, quiet = TRUE)
  still <- missing[
    !vapply(missing, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(still) > 0L) {
    stop(
      "Unable to install R packages: ",
      paste(still, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Install Python packages declared for a study
#' @keywords internal
install_study_python_packages <- function(meta, ctx, study_root = NULL) {
  deps <- study_declared_python_packages(meta)
  if (length(deps) == 0L) {
    return(invisible(TRUE))
  }
  rep_stub <- list(
    id = "maintainer_install",
    engine = "python",
    dependencies = deps
  )
  ensure_python_dependencies(
    rep_stub,
    paper_meta = meta$paper %||% NULL,
    ctx = ctx,
    meta = meta,
    install_missing = TRUE
  )
}

#' Install Stata SSC / GitHub packages declared for a study
#' @keywords internal
install_study_stata_packages <- function(study_root, meta) {
  if (is.null(study_root) || !dir.exists(study_root)) {
    return(invisible(FALSE))
  }
  install_stata_dependencies(
    study_root,
    meta = meta,
    install_deps = TRUE,
    force = TRUE
  )
}

#' Install dependencies for a package-backed study
#'
#' Loads or installs the study package, then installs declared R, Python, and
#' Stata dependencies from its \code{replication.yml}. Does not build
#' \code{inst/report/outputs/} — use [build_study_outputs()] for that.
#'
#' @param meta Parsed replication metadata with \code{paper.package}.
#' @param ctx Paper context.
#' @keywords internal
install_package_dependencies <- function(meta, ctx) {
  pkg <- as.character(meta$paper$package[[1]] %||% "")
  if (!nzchar(pkg)) {
    stop("Package-backed study is missing paper.package.", call. = FALSE)
  }
  ensure_replication_package(pkg, meta = meta, ctx = ctx)
  full_meta <- read_package_replication_meta(pkg)
  pkg_root <- package_source_root(pkg)

  with_maintainer_install_opts({
    install_study_r_packages(full_meta)
    if (!is.null(pkg_root) && dir.exists(pkg_root)) {
      install_study_python_packages(full_meta, ctx, study_root = pkg_root)
      install_study_stata_packages(pkg_root, full_meta)
    }
  })
  invisible(TRUE)
}

#' Install dependencies for one folder-backed or registry study
#'
#' Maintainer setup only. Installs declared R CRAN packages, Python pip
#' packages, and runs study Stata install scripts (\code{install_stata_deps.do})
#' once. Works for **folder-backed** and **package-backed** registry studies.
#' Does **not** build display outputs — use [build_study_outputs()] for that.
#'
#' Live Run and Shiny probe dependencies only; call this function (or
#' [install_registry_dependencies()]) when onboarding a machine.
#'
#' @param location Study DOI, registry handle, local path, or GitHub slug.
#' @param registry_root Optional registry checkout for monorepo dev.
#' @param repo,folder Optional registry row hints.
#' @param from_registry_index Logical. When \code{TRUE} (set by
#'   [install_registry_dependencies()]), never treat blank input or a sibling
#'   folder name in \code{getwd()} as the local study.
#' @return Invisibly \code{TRUE} on success.
#' @seealso [check_study_compatibility()], [build_study_outputs()],
#'   [install_registry_dependencies()]
#'
#' @examples
#' \dontrun{
#' install_study_dependencies("10.1017/S0003055426101749")
#' install_study_dependencies("path/to/study-repo")
#' }
#'
#' @export
install_study_dependencies <- function(
  location,
  registry_root = NULL,
  repo = NULL,
  folder = NULL,
  from_registry_index = FALSE
) {
  old_root <- getOption("replicateEverything.registry_root", NULL)
  if (!is.null(registry_root) && nzchar(registry_root)) {
    on.exit(
      options(replicateEverything.registry_root = old_root),
      add = TRUE
    )
    options(replicateEverything.registry_root = registry_root)
  }

  loc <- trimws(as.character(location[[1]] %||% location))
  if (
    isTRUE(from_registry_index) &&
      (!nzchar(loc) || is_local_doi_query(loc))
  ) {
    folder_hint <- trimws(as.character(folder[[1]] %||% folder %||% ""))
    if (nzchar(folder_hint)) {
      loc <- folder_hint
    } else {
      stop(
        "Registry index row has no resolvable study location (doi, handle, or folder).",
        call. = FALSE
      )
    }
  }

  is_local <- !isTRUE(from_registry_index) &&
    dir.exists(loc) &&
    file.exists(file.path(loc, "replication.yml"))

  if (is_local) {
    study_root <- normalizePath(loc, winslash = "/", mustWork = FALSE)
    meta <- read_study_replication_yaml(study_root)
    if (is.null(meta)) {
      stop("Missing replication.yml in ", study_root, call. = FALSE)
    }
    doi <- normalize_doi(meta$paper$doi)
    ctx <- paper_context(doi, repo = repo, folder = folder)
    kind <- "folder"
  } else {
    doi <- prepare_doi_for_replication(
      loc,
      allow_local = !isTRUE(from_registry_index)
    )
    meta <- get_replication_meta(
      doi,
      repo = repo,
      folder = folder
    )
    ctx <- paper_context(doi, repo = repo, folder = folder)
    kind <- replication_kind(meta, ctx)
    if (identical(kind, "package")) {
      with_maintainer_install_opts({
        message("Installing dependencies for ", doi, " (package ", meta$paper$package[[1]], ") ...")
        install_package_dependencies(meta, ctx)
      })
      message("Dependency install finished for ", doi)
      return(invisible(TRUE))
    }
    if (!identical(kind, "folder")) {
      stop(
        "Study ", doi, " is registry-embedded (not folder- or package-backed). ",
        "Install dependencies manually or use build_study_outputs() from ",
        "the registry checkout.",
        call. = FALSE
      )
    }
    study_root <- ensure_study_folder_local(meta, ctx)
  }

  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  meta <- complete_folder_study_meta(meta, study_root)

  with_maintainer_install_opts({
    message("Installing dependencies for ", doi, " ...")
    install_study_r_packages(meta)
    install_study_python_packages(meta, ctx, study_root = study_root)
    install_study_stata_packages(study_root, meta)
  })

  message("Dependency install finished for ", doi)
  invisible(TRUE)
}

#' Resolve a registry index row to a study location for maintainer APIs
#'
#' Rows without a DOI (handle-only stubs) must not pass an empty string to
#' [install_study_dependencies()], because blank input means "local study in
#' getwd()".
#'
#' @param row One row from [load_index()].
#' @return Character DOI, handle, or folder slug.
#' @keywords internal
resolve_index_study_location <- function(row) {
  doi <- index_row_field(row, "doi")
  if (nzchar(doi)) {
    return(doi)
  }
  handle <- index_row_field(row, "handle")
  if (nzchar(handle)) {
    return(handle)
  }
  folder <- index_row_field(row, "folder")
  if (nzchar(folder)) {
    return(folder)
  }
  stop(
    "Registry index row is missing doi, handle, and folder.",
    call. = FALSE
  )
}

#' Format a registry bulk-install failure with row context
#' @keywords internal
registry_install_error_message <- function(
  error,
  row,
  i,
  n,
  location,
  repo = NULL,
  folder = NULL
) {
  paste(
    conditionMessage(error),
    "",
    paste0("Registry row ", i, "/", n, ":"),
    paste0("  location: ", location),
    paste0("  folder: ", index_row_field(row, "folder")),
    paste0("  handle: ", index_row_field(row, "handle")),
    paste0("  doi: ", index_row_field(row, "doi")),
    paste0("  repo: ", index_row_field(row, "repo", repo %||% "")),
    "",
    "Resolution path: index row -> registry stub -> study GitHub repo ",
    "(install_registry_dependencies never uses getwd() as the study).",
    sep = "\n"
  )
}

#' Install dependencies for every study in the registry index
#'
#' Maintainer setup for a shared server or audit machine. Calls
#' [install_study_dependencies()] for each row in [load_index()]. Failures are
#' collected and reported; other studies continue.
#'
#' @param registry_root Optional registry checkout path.
#' @param verbose Logical. Print progress lines.
#' @return Invisibly, a named list of per-DOI results (\code{ok} / \code{error}).
#' @seealso [install_study_dependencies()], [check_study_compatibility()]
#'
#' @examples
#' \dontrun{
#' install_registry_dependencies()
#' }
#'
#' @export
install_registry_dependencies <- function(
  registry_root = NULL,
  verbose = TRUE
) {
  old_root <- getOption("replicateEverything.registry_root", NULL)
  if (!is.null(registry_root) && nzchar(registry_root)) {
    on.exit(
      options(replicateEverything.registry_root = old_root),
      add = TRUE
    )
    options(replicateEverything.registry_root = registry_root)
  }

  idx <- load_index()
  if (is.null(idx) || nrow(idx) == 0L) {
    stop("Registry index is empty.", call. = FALSE)
  }

  results <- list()

  for (i in seq_len(nrow(idx))) {
    row <- idx[i, , drop = FALSE]
    location <- resolve_index_study_location(row)
    doi <- index_row_field(row, "doi")
    result_key <- if (nzchar(doi)) doi else location
    repo <- index_row_field(row, "repo", default = NA_character_)
    repo <- if (nzchar(repo)) repo else NULL
    folder <- index_row_field(row, "folder", default = NA_character_)
    folder <- if (nzchar(folder)) folder else NULL
    if (verbose) {
      label <- if (nzchar(doi)) doi else paste0(location, " (no DOI)")
      message("[", i, "/", nrow(idx), "] ", label)
    }
    results[[result_key]] <- tryCatch(
      {
        install_study_dependencies(
          location,
          registry_root = registry_root,
          repo = repo,
          folder = folder,
          from_registry_index = TRUE
        )
        list(ok = TRUE)
      },
      error = function(e) {
        msg <- registry_install_error_message(
          e,
          row = row,
          i = i,
          n = nrow(idx),
          location = location,
          repo = repo,
          folder = folder
        )
        if (verbose) {
          message("  failed: ", msg)
        }
        list(ok = FALSE, error = msg)
      }
    )
  }

  failed <- names(results)[!vapply(results, function(x) isTRUE(x$ok), logical(1))]
  if (length(failed) > 0L) {
    warning(
      "Dependency install failed for ",
      length(failed),
      " study/studies: ",
      paste(failed, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(results)
}

#' Check yaml-declared dependencies against this machine (no installs)
#'
#' Reads \code{languages:}, \code{paper.dependencies},
#' \code{python_dependencies:}, \code{stata_packages:}, and
#' \code{stata_deps_probe:} from the study \code{replication.yml} and probes
#' the local R, Python, and Stata stack. Alias for
#' [study_system_compatibility()].
#'
#' @inheritParams study_system_compatibility
#' @return A \code{study_system_compatibility} list with \code{ready},
#'   \code{install_needed}, and per-engine \code{dependencies}.
#' @seealso [install_study_dependencies()], [maintainer_dependency_hint()]
#'
#' @examples
#' \dontrun{
#' check_study_compatibility("10.1017/S0003055426101749")
#' }
#'
#' @export
check_study_compatibility <- function(
  doi,
  repo = NULL,
  folder = NULL,
  registry_root = NULL,
  materialize_study = TRUE,
  include_registry_audit = FALSE
) {
  study_system_compatibility(
    doi = doi,
    repo = repo,
    folder = folder,
    registry_root = registry_root,
    materialize_study = materialize_study,
    include_registry_audit = include_registry_audit
  )
}

#' Stop when dependencies are missing before a live replication run
#'
#' @inheritParams render_replication
#' @keywords internal
assert_study_ready_for_replication <- function(
  doi,
  meta = NULL,
  repo = NULL,
  folder = NULL,
  install_deps = FALSE,
  engines = NULL
) {
  if (allow_dependency_install(install_deps)) {
    return(invisible(TRUE))
  }

  if (is.null(meta)) {
    meta <- get_replication_meta(doi, repo = repo, folder = folder)
  }
  ctx <- tryCatch(
    paper_context(doi, repo = repo, folder = folder),
    error = function(e) list()
  )
  eval <- evaluate_study_compatibility(
    meta,
    ctx,
    do_materialize = TRUE,
    engines = engines
  )
  if (isTRUE(eval$ready)) {
    return(invisible(TRUE))
  }

  compat <- c(list(doi = doi), eval, list(registry_audit = list(available = FALSE)))
  class(compat) <- "study_system_compatibility"
  stop(
    maintainer_dependency_hint(doi = doi, audit = compat),
    call. = FALSE
  )
}

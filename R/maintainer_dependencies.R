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

#' Install dependencies for one folder-backed or registry study
#'
#' Maintainer setup only. Installs declared R CRAN packages, Python pip
#' packages, and runs study Stata install scripts (\code{install_stata_deps.do})
#' once. Does **not** build display artifacts — use [build_study_artifacts()] for
#' that.
#'
#' Live Run and Shiny probe dependencies only; call this function (or
#' [install_registry_dependencies()]) when onboarding a machine.
#'
#' @param location Study DOI, registry handle, local path, or GitHub slug.
#' @param registry_root Optional registry checkout for monorepo dev.
#' @param repo,folder Optional registry row hints.
#' @return Invisibly \code{TRUE} on success.
#' @seealso [check_study_compatibility()], [build_study_artifacts()],
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
  folder = NULL
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
  is_local <- dir.exists(loc) &&
    file.exists(file.path(loc, "replication.yml"))

  if (is_local) {
    study_root <- normalizePath(loc, winslash = "/", mustWork = FALSE)
    meta <- read_study_replication_yaml(study_root)
    if (is.null(meta)) {
      stop("Missing replication.yml in ", study_root, call. = FALSE)
    }
    doi <- normalize_doi(meta$paper$doi)
    ctx <- paper_context(doi, repo = repo, folder = folder)
  } else {
    doi <- prepare_doi_for_replication(loc)
    meta <- get_replication_meta(
      doi,
      repo = repo,
      folder = folder
    )
    ctx <- paper_context(doi, repo = repo, folder = folder)
    if (isTRUE(is_package_replication(meta))) {
      pkg <- as.character(meta$paper$package[[1]] %||% "")
      stop(
        "Package-backed study ", pkg, ".\n",
        "Install its R dependencies with build_package_artifacts(",
        shQuote(pkg, type = "sh"), ", install_deps = TRUE).",
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

  results <- vector("list", nrow(idx))
  names(results) <- idx$doi

  for (i in seq_len(nrow(idx))) {
    row <- idx[i, , drop = FALSE]
    doi <- as.character(row$doi[[1]])
    repo <- if ("repo" %in% names(row)) row$repo[[1]] else NULL
    folder <- if ("folder" %in% names(row)) row$folder[[1]] else NULL
    if (verbose) {
      message("[", i, "/", nrow(idx), "] ", doi)
    }
    results[[doi]] <- tryCatch(
      {
        install_study_dependencies(
          doi,
          registry_root = registry_root,
          repo = repo,
          folder = folder
        )
        list(ok = TRUE)
      },
      error = function(e) {
        if (verbose) {
          message("  failed: ", conditionMessage(e))
        }
        list(ok = FALSE, error = conditionMessage(e))
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
  install_deps = FALSE
) {
  if (allow_dependency_install(install_deps)) {
    return(invisible(TRUE))
  }

  if (is.null(meta)) {
    meta <- get_replication_meta(doi, repo = repo, folder = folder)
  }

  if (isTRUE(is_package_replication(meta))) {
    pkgs <- study_declared_r_packages(meta)
    missing <- pkgs[
      !vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
    ]
    if (length(missing) == 0L) {
      return(invisible(TRUE))
    }
    pkg <- as.character(meta$paper$package[[1]] %||% "")
    stop(
      maintainer_dependency_hint(
        doi = doi,
        scope = "package",
        package = pkg,
        missing_r = missing
      ),
      call. = FALSE
    )
  }

  pkgs <- study_declared_r_packages(meta)
  missing_r <- pkgs[
    !vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing_r) > 0L) {
    stop(
      maintainer_dependency_hint(doi = doi, missing_r = missing_r),
      call. = FALSE
    )
  }

  compat <- study_system_compatibility(
    doi = doi,
    repo = repo,
    folder = folder,
    materialize_study = TRUE,
    include_registry_audit = FALSE
  )
  if (isTRUE(compat$ready)) {
    return(invisible(TRUE))
  }

  stop(
    maintainer_dependency_hint(doi = doi, audit = compat),
    call. = FALSE
  )
}

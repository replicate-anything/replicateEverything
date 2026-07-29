# Yaml-declared system compatibility checks (probe only — no installs).

.registry_audit_cache <- new.env(parent = emptyenv())

#' Normalize a yaml list field to a character vector
#' @keywords internal
yaml_string_list <- function(...) {
  vals <- unlist(list(...), use.names = FALSE)
  vals <- stats::na.omit(as.character(vals))
  unique(vals[nzchar(vals)])
}

#' Languages declared in replication.yml
#'
#' Prefer top-level \code{languages:} or \code{paper.languages:}. When omitted,
#' infers from \code{engine:} on \code{steps:} entries.
#'
#' @param meta Parsed replication metadata.
#' @return Character vector of \code{r}, \code{stata}, and/or \code{python}.
#' @keywords internal
study_declared_languages <- function(meta) {
  raw <- yaml_string_list(
    meta$languages %||% NULL,
    meta$paper$languages %||% NULL
  )
  raw <- tolower(raw)
  raw[raw %in% c("py")] <- "python"
  raw[raw %in% c("wolfram", "wolframscript")] <- "mathematica"
  # Include mathematica for registry / Studies display (hammer notes); runnable
  # engines remain r / stata / python elsewhere.
  raw <- unique(raw[raw %in% c("r", "stata", "python", "mathematica")])
  if (length(raw) > 0L) {
    return(raw)
  }

  entries <- tryCatch(collect_study_step_entries(meta), error = function(e) list())
  if (length(entries) == 0L) {
    return(character(0))
  }
  engines <- vapply(
    entries,
    function(x) replication_engine(x, meta$paper),
    character(1)
  )
  unique(engines[nzchar(engines)])
}

#' R packages declared in replication.yml
#'
#' Uses \code{paper.dependencies} and optional top-level \code{r_dependencies:}.
#'
#' @param meta Parsed replication metadata.
#' @keywords internal
study_declared_r_packages <- function(meta) {
  yaml_string_list(
    meta$paper$dependencies %||% NULL,
    meta$r_dependencies %||% NULL,
    meta$paper$r_dependencies %||% NULL
  )
}

#' Python packages declared in replication.yml
#'
#' Uses top-level \code{python_dependencies:} or \code{paper.python_dependencies:}.
#' When omitted, aggregates \code{dependencies:} from python engine entries.
#'
#' @param meta Parsed replication metadata.
#' @keywords internal
study_declared_python_packages <- function(meta) {
  declared <- yaml_string_list(
    meta$python_dependencies %||% NULL,
    meta$paper$python_dependencies %||% NULL
  )
  if (length(declared) > 0L) {
    return(declared)
  }
  deps <- character(0)
  entries <- tryCatch(collect_study_step_entries(meta), error = function(e) list())
  for (entry in entries) {
    if (identical(replication_engine(entry, meta$paper), "python")) {
      deps <- c(deps, unlist(entry$dependencies %||% list(), use.names = FALSE))
    }
  }
  yaml_string_list(deps)
}

#' Probe CRAN packages (check only — no install)
#' @keywords internal
probe_r_packages <- function(packages) {
  packages <- unique(packages[nzchar(packages)])
  if (length(packages) == 0L) {
    return(list(ok = TRUE, required = character(0), missing = character(0)))
  }
  missing <- packages[
    !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  list(
    ok = length(missing) == 0L,
    required = packages,
    missing = missing
  )
}

#' Probe Stata from yaml declarations (executable + probe or stata_packages)
#'
#' Always reports the resolved Stata executable (\code{stata_executable} /
#' \code{stata_label}) alongside \code{ok} / \code{missing}, so
#' [check_study_compatibility()] output makes it obvious which Stata binary
#' was probed - and whether it's the same one [install_dependencies()] used
#' (see [stata_executable_label()]).
#' @keywords internal
probe_stata_from_yaml <- function(meta, study_root = NULL) {
  if (!is.null(study_root) && nzchar(study_root) && dir.exists(study_root)) {
    meta <- complete_folder_study_meta(meta, study_root)
  }
  stata <- find_stata_executable()
  stata_label <- stata_executable_label(stata)
  if (is.null(stata)) {
    return(list(
      ok = FALSE,
      required = stata_deps_package_names(meta),
      missing = "Stata executable",
      probe = stata_deps_probe_label(study_root %||% "", meta = meta),
      message = "Stata not found on PATH",
      stata_executable = NULL,
      stata_label = stata_label
    ))
  }

  probe_label <- stata_deps_probe_label(study_root %||% "", meta = meta)
  pkgs <- stata_deps_package_names(meta)
  needs_probe_file <- length(stata_deps_probe_scripts(study_root %||% ".", meta = meta)) > 0L

  workdir <- study_root
  if (needs_probe_file && (is.null(workdir) || !dir.exists(workdir))) {
    return(list(
      ok = NA,
      required = pkgs,
      missing = character(0),
      probe = probe_label,
      message = "Study folder required to run stata_deps_probe script",
      stata_executable = stata,
      stata_label = stata_label
    ))
  }
  if (is.null(workdir) || !dir.exists(workdir)) {
    workdir <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  }

  if (identical(probe_label, "not configured") && length(pkgs) == 0L) {
    return(list(
      ok = TRUE,
      required = character(0),
      missing = character(0),
      probe = probe_label,
      message = "Stata available (no packages declared in yaml)",
      stata_executable = stata,
      stata_label = stata_label
    ))
  }

  satisfied <- tryCatch(
    stata_dependencies_satisfied(
      workdir,
      meta = meta,
      timeout = as.integer(
        getOption("replicateEverything.stata_deps_probe_timeout", 120L)[1]
      )
    ),
    error = function(e) FALSE
  )

  if (isTRUE(satisfied)) {
    return(list(
      ok = TRUE,
      required = pkgs,
      missing = character(0),
      probe = probe_label,
      message = paste0("Probe passed (", stata_label, ")"),
      stata_executable = stata,
      stata_label = stata_label
    ))
  }

  # `stata_dependencies_satisfied()` attributes the failure to the specific
  # package it can attribute (from the probe's exit code), falling back to
  # every declared package only when it genuinely cannot tell which one.
  attributed_missing <- attr(satisfied, "missing", exact = TRUE)
  missing <- if (!is.null(attributed_missing) && length(attributed_missing)) {
    attributed_missing
  } else if (length(pkgs)) {
    pkgs
  } else {
    "Stata packages (probe failed)"
  }

  list(
    ok = FALSE,
    required = pkgs,
    missing = missing,
    probe = probe_label,
    message = paste0("Dependency probe did not pass (", stata_label, ")"),
    stata_executable = stata,
    stata_label = stata_label
  )
}

#' Probe Python executable and yaml-declared imports
#' @keywords internal
probe_python_from_yaml <- function(packages) {
  packages <- unique(packages[nzchar(packages)])
  python <- tryCatch(
    find_python_executable(packages),
    error = function(e) NULL
  )
  if (is.null(python)) {
    return(list(
      ok = FALSE,
      required = packages,
      missing = if (length(packages)) packages else "Python executable",
      python = NULL,
      message = "Python not found on PATH"
    ))
  }
  if (length(packages) == 0L) {
    return(list(
      ok = TRUE,
      required = character(0),
      missing = character(0),
      python = python,
      message = "Python available (no packages declared in yaml)"
    ))
  }
  missing <- python_missing_dependencies(python, packages)
  list(
    ok = length(missing) == 0L,
    required = packages,
    missing = missing,
    python = python,
    message = if (length(missing) == 0L) "Imports OK" else "Missing imports"
  )
}

#' Load the full registry audit snapshot (cached per session)
#' @keywords internal
load_registry_audit_snapshot <- function(registry_root = NULL) {
  cache_key <- registry_root %||% "_default"
  if (exists(cache_key, envir = .registry_audit_cache, inherits = FALSE)) {
    return(get(cache_key, envir = .registry_audit_cache))
  }

  snap <- NULL
  rds_path <- registry_audit_rds_path(registry_root)
  if (nzchar(rds_path) && file.exists(rds_path)) {
    snap <- tryCatch(readRDS(rds_path), error = function(e) NULL)
  }

  if (is.null(snap)) {
    url <- paste0(
      "https://raw.githubusercontent.com/",
      DEFAULT_REGISTRY_REPO,
      "/main/audit_latest.rds"
    )
    dest <- tempfile(fileext = ".rds")
    ok <- tryCatch(
      {
        utils::download.file(url, dest, quiet = TRUE, mode = "wb")
        TRUE
      },
      error = function(e) FALSE
    )
    if (isTRUE(ok) && file.exists(dest)) {
      snap <- tryCatch(readRDS(dest), error = function(e) NULL)
      unlink(dest)
    }
  }

  if (!is.null(snap)) {
    assign(cache_key, snap, envir = .registry_audit_cache)
  }
  snap
}

#' Registry audit rows for one study DOI
#' @keywords internal
study_registry_audit_results <- function(doi, registry_root = NULL) {
  snap <- load_registry_audit_snapshot(registry_root)
  if (is.null(snap) || is.null(snap$results) || nrow(snap$results) == 0L) {
    return(list(
      available = FALSE,
      finished_at = NULL,
      total = 0L,
      passed = 0L,
      failed = 0L,
      timed_out = 0L,
      skipped = 0L,
      failures = NULL,
      skips = NULL
    ))
  }

  doi_norm <- normalize_doi(doi)
  results <- snap$results
  results$doi_norm <- vapply(results$doi, normalize_doi, character(1))
  sub <- results[results$doi_norm == doi_norm, , drop = FALSE]

  if (nrow(sub) == 0L) {
    return(list(
      available = TRUE,
      finished_at = format(snap$finished_at, "%Y-%m-%d", tz = "UTC"),
      total = 0L,
      passed = 0L,
      failed = 0L,
      timed_out = 0L,
      skipped = 0L,
      failures = NULL,
      skips = NULL,
      not_in_audit = TRUE
    ))
  }

  passed <- sum(sub$success %in% TRUE, na.rm = TRUE)
  is_skipped <- if ("skipped" %in% names(sub)) {
    as.logical(sub$skipped) %in% TRUE
  } else {
    rep(FALSE, nrow(sub))
  }
  skipped <- sum(is_skipped, na.rm = TRUE)
  failed <- sum(sub$success %in% FALSE, na.rm = TRUE)
  timed_out <- if ("timed_out" %in% names(sub)) {
    sum(as.logical(sub$timed_out) %in% TRUE, na.rm = TRUE)
  } else {
    0L
  }
  fail_rows <- sub[sub$success %in% FALSE & !is_skipped, , drop = FALSE]
  skip_rows <- sub[is_skipped, , drop = FALSE]
  failures <- NULL
  if (nrow(fail_rows) > 0L) {
    keep <- intersect(
      c("object", "object_label", "engine", "error_snippet", "timed_out", "skipped", "timeout_seconds"),
      names(fail_rows)
    )
    failures <- fail_rows[, keep, drop = FALSE]
  }
  skips <- NULL
  if (nrow(skip_rows) > 0L) {
    keep <- intersect(
      c("object", "object_label", "engine", "error_snippet", "skipped"),
      names(skip_rows)
    )
    skips <- skip_rows[, keep, drop = FALSE]
  }

  list(
    available = TRUE,
    finished_at = format(snap$finished_at, "%Y-%m-%d", tz = "UTC"),
    total = nrow(sub),
    passed = passed,
    failed = failed,
    timed_out = as.integer(timed_out),
    skipped = as.integer(skipped),
    failures = failures,
    skips = skips,
    not_in_audit = FALSE
  )
}

#' Probe declared R / Python / Stata dependencies from yaml
#'
#' @param meta Parsed replication metadata.
#' @param study_root Local study or package source root (for Stata probes).
#' @return List with \code{languages}, \code{dependencies}, \code{ready},
#'   \code{install_needed}.
#' @keywords internal
probe_study_engine_dependencies <- function(meta, study_root = NULL, engines = NULL) {
  languages <- study_declared_languages(meta)
  if (!is.null(engines) && length(engines) > 0L) {
    engines <- unique(tolower(as.character(engines)))
    engines <- engines[engines %in% languages]
    languages <- engines
  }
  dependencies <- list()
  ready <- TRUE
  install_needed <- FALSE

  if ("r" %in% languages) {
    r_probe <- probe_r_packages(study_declared_r_packages(meta))
    dependencies$r <- c(r_probe, list(kind = "cran"))
    if (!isTRUE(r_probe$ok)) {
      ready <- FALSE
      install_needed <- TRUE
    }
  }

  if ("stata" %in% languages) {
    st_probe <- probe_stata_from_yaml(meta, study_root = study_root)
    dependencies$stata <- c(st_probe, list(kind = "stata"))
    if (isFALSE(st_probe$ok)) {
      ready <- FALSE
      install_needed <- TRUE
    }
  }

  if ("python" %in% languages) {
    py_probe <- probe_python_from_yaml(study_declared_python_packages(meta))
    dependencies$python <- c(py_probe, list(kind = "python"))
    if (!isTRUE(py_probe$ok)) {
      ready <- FALSE
      install_needed <- TRUE
    }
  }

  list(
    languages = languages,
    dependencies = dependencies,
    ready = ready,
    install_needed = install_needed
  )
}

#' Evaluate yaml-declared compatibility from parsed metadata
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @param do_materialize Materialize folder or package materials when \code{TRUE}.
#' @return List with \code{kind}, \code{languages}, \code{dependencies},
#'   \code{ready}, \code{install_needed}.
#' @keywords internal
evaluate_study_compatibility <- function(
  meta,
  ctx,
  do_materialize = TRUE,
  engines = NULL
) {
  kind <- replication_kind(meta, ctx)

  languages <- character(0)
  dependencies <- list()
  ready <- TRUE
  install_needed <- FALSE
  study_root <- NULL

  if (identical(kind, "package")) {
    pkg <- as.character(meta$paper$package[[1]] %||% "")
    if (isTRUE(do_materialize)) {
      mat <- tryCatch(
        materialize_study(meta, ctx),
        error = function(e) NULL
      )
      if (!is.null(mat)) {
        study_root <- mat$root
        meta <- mat$meta
      }
    }
    pkg_ok <- nzchar(pkg) && replication_package_usable(pkg)
    if (!isTRUE(do_materialize) && pkg_ok) {
      study_root <- package_source_root(pkg)
      meta <- tryCatch(
        read_package_replication_meta(pkg),
        error = function(e) meta
      )
    }
    dependencies$package <- list(
      ok = pkg_ok,
      required = if (nzchar(pkg)) pkg else character(0),
      missing = if (pkg_ok) character(0) else pkg,
      kind = "replication_package"
    )
    if (!pkg_ok) {
      ready <- FALSE
      install_needed <- TRUE
    }
  } else if (identical(kind, "folder")) {
    declared <- study_declared_languages(meta)
    active_langs <- declared
    if (!is.null(engines) && length(engines) > 0L) {
      engines_norm <- unique(tolower(as.character(engines)))
      active_langs <- engines_norm[engines_norm %in% declared]
    }
    languages <- declared
    study_root <- resolve_study_folder_path(meta, ctx)

    needs_stata_folder <- "stata" %in% active_langs &&
      length(stata_deps_probe_scripts(study_root %||% ".", meta = meta)) > 0L

    if (
      isTRUE(do_materialize) &&
      (needs_stata_folder || length(active_langs) > 0L) &&
      (is.null(study_root) || !dir.exists(study_root))
    ) {
      study_root <- tryCatch(
        ensure_study_folder_local(meta, ctx),
        error = function(e) NULL
      )
    }

    if (!is.null(study_root) && dir.exists(study_root)) {
      meta <- complete_folder_study_meta(meta, study_root)
      languages <- study_declared_languages(meta)
    }
  }

  engine_probe <- probe_study_engine_dependencies(meta, study_root = study_root, engines = engines)
  languages <- unique(c(languages, engine_probe$languages))
  dependencies <- c(dependencies, engine_probe$dependencies)
  if (!isTRUE(engine_probe$ready)) {
    ready <- FALSE
    install_needed <- TRUE
  }
  if (identical(kind, "package") && !isTRUE(dependencies$package$ok %||% TRUE)) {
    ready <- FALSE
    install_needed <- TRUE
  }

  list(
    kind = kind,
    languages = languages,
    engines = languages,
    dependencies = dependencies,
    ready = ready,
    install_needed = install_needed
  )
}

#' Check yaml-declared dependencies against the local system
#'
#' Reads \code{languages:}, \code{paper.dependencies}, \code{python_dependencies:},
#' \code{stata_packages:}, and \code{stata_deps_probe:} from \code{replication.yml}
#' and probes this machine only (no installs).
#'
#' @param doi Study DOI.
#' @param repo,folder Registry row hints.
#' @param registry_root Optional local registry checkout.
#' @param materialize_study Materialize folder-backed study repo for Stata probe scripts.
#' @param include_registry_audit Include latest registry \code{audit_latest.rds} summary.
#' @return A \code{study_system_compatibility} list.
#' @keywords internal
study_system_compatibility <- function(
  doi,
  repo = NULL,
  folder = NULL,
  registry_root = NULL,
  materialize_study = TRUE,
  include_registry_audit = FALSE
) {
  doi <- prepare_doi_for_replication(doi)
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  eval <- evaluate_study_compatibility(meta, ctx, do_materialize = materialize_study)

  structure(
    c(
      list(doi = doi),
      eval,
      list(
        registry_audit = if (isTRUE(include_registry_audit)) {
          study_registry_audit_results(doi, registry_root = registry_root)
        } else {
          list(available = FALSE)
        }
      )
    ),
    class = "study_system_compatibility"
  )
}

#' @rdname study_system_compatibility
#' @keywords internal
study_readiness_audit <- function(...) {
  compat <- study_system_compatibility(...)
  compat$class <- c("study_readiness_audit", "study_system_compatibility")
  compat
}

# Legacy names used in tests
study_audit_engines <- study_declared_languages
study_audit_r_packages <- study_declared_r_packages
study_audit_python_packages <- study_declared_python_packages

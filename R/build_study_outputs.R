#' Build display outputs for a study repository
#'
#' Runs pipeline prep steps from `replication.yml` when present, then every
#' registered table and figure, and writes formatted outputs plus
#' `manifest.json`. Works for folder-backed studies (`outputs/`) and
#' package-backed studies (`inst/report/outputs/` or `inst/report/artifacts/`).
#'
#' @param location Local study path, GitHub address, or installed package
#'   name. Defaults to `"."` when the working directory contains
#'   `replication.yml` or `DESCRIPTION`.
#' @param install_deps Logical. Install missing CRAN, pip, and Stata dependencies
#'   when `TRUE`.
#' @param ids Optional character vector of replication ids to build. When
#'   `NULL`, builds every figure and table in `replication.yml`.
#' @param registry_root Optional registry checkout path for monorepo dev
#'   (folder studies only).
#' @param output_dir Optional output directory (package studies only). Defaults to
#'   the package report outputs directory.
#' @param force_prep Logical. Re-run prep steps even when outputs already exist.
#' @param only_missing Logical. When `TRUE`, skip replications whose artifacts
#'   already exist (see [artifact_available()]).
#' @return Invisibly, a list with `output_dir`, `manifest`, and per-id status.
#'
#' @seealso [build_outputs()] for registry-wide or DOI-scoped builds.
#'
#' @examples
#' \dontrun{
#' build_study_outputs(".", install_deps = TRUE)
#' build_study_outputs("rep1371journalpone0278337", install_deps = TRUE)
#' build_study_outputs(".", only_missing = TRUE)
#' }
#'
#' @export
build_study_outputs <- function(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL,
  output_dir = NULL,
  force_prep = FALSE,
  only_missing = FALSE
) {
  loc <- trimws(as.character(location[[1]] %||% location))
  root <- tryCatch(
    resolve_study_root(location),
    error = function(e) NULL
  )
  if (!is.null(root)) {
    kind <- detect_study_kind_from_root(root)
    if (identical(kind, "package")) {
      return(build_package_outputs_impl(
        package = package_name_from_root(root),
        install_deps = install_deps,
        ids = ids,
        output_dir = output_dir,
        force_prep = force_prep,
        only_missing = only_missing
      ))
    }
    return(build_folder_outputs_impl(
      location = root,
      install_deps = install_deps,
      ids = ids,
      registry_root = registry_root,
      force_prep = force_prep,
      only_missing = only_missing
    ))
  }
  if (looks_like_study_alias(loc)) {
    stop(
      "Could not resolve study location: ", loc, ". ",
      "Pass the study repo path (e.g. \"rep-10.5555-cahw\"), call ",
      "configure_local_monorepo(), or set options(replicateEverything.registry_root = ...).",
      call. = FALSE
    )
  }
  build_package_outputs_impl(
    package = loc,
    install_deps = install_deps,
    ids = ids,
    output_dir = output_dir,
    force_prep = force_prep,
    only_missing = only_missing
  )
}

# Package-backed implementation (unexported).
build_package_outputs_impl <- function(
  package,
  install_deps = TRUE,
  ids = NULL,
  output_dir = NULL,
  force_prep = FALSE,
  only_missing = FALSE
) {
  package <- as.character(package[[1]])
  ensure_replication_package(package)
  meta <- read_package_replication_meta(package)
  paper <- meta$paper
  if (is.null(paper$doi) || !nzchar(as.character(paper$doi[[1]]))) {
    stop("paper.doi is required in replication.yml", call. = FALSE)
  }

  doi <- normalize_doi(paper$doi)
  folder <- doi_to_registry_folder(doi)
  ctx <- paper_context(doi, folder = folder)
  pkg_root <- package_source_root(package)
  if (is.null(output_dir) || !nzchar(output_dir)) {
    default_dir <- study_artifact_dir(meta, ctx, installed = FALSE, package = package)
    if (is.null(default_dir)) {
      if (is.null(pkg_root)) {
        stop("Could not resolve package source root for ", package, call. = FALSE)
      }
      output_dir <- file.path(pkg_root, "inst", "report", "artifacts")
    } else {
      output_dir <- default_dir
    }
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  display_reps <- folder_display_replications(meta)
  if (!is.null(ids)) {
    display_reps <- display_reps[vapply(display_reps, function(x) {
      x$id %in% ids
    }, logical(1))]
    missing_ids <- setdiff(ids, vapply(display_reps, function(x) x$id, character(1)))
    if (length(missing_ids)) {
      stop(
        "Unknown replication id(s): ", paste(missing_ids, collapse = ", "),
        call. = FALSE
      )
    }
  }

  display_reps <- filter_replications_only_missing(
    display_reps,
    doi,
    folder = folder,
    only_missing = only_missing,
    study_root = pkg_root
  )

  if (length(display_reps) == 0) {
    if (isTRUE(only_missing)) {
      message("All artifacts present; skipping build.")
      return(invisible(list(
        artifact_dir = output_dir,
        manifest = list(replications = list()),
        manifest_path = study_manifest_path(meta, ctx, installed = FALSE, package = package)
      )))
    }
    stop("No figure/table replications to build.", call. = FALSE)
  }

  prep_steps <- prep_steps_for_build(
    meta,
    if (is.null(ids)) NULL else display_reps
  )
  prep_result <- run_build_prep_steps(
    meta,
    ctx,
    doi,
    prep_steps,
    install_deps = install_deps,
    force = force_prep,
    study_root = pkg_root
  )

  display_result <- build_display_artifact_entries(
    display_reps,
    doi = doi,
    artifact_dir = output_dir,
    folder = folder,
    install_deps = install_deps,
    study_root = pkg_root
  )

  failures <- c(prep_result$failures, display_result$failures)

  manifest <- list(
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    folder = folder,
    doi = doi,
    package = package,
    prep = prep_result$statuses,
    replications = display_result$manifest
  )

  manifest_path <- study_manifest_path(meta, ctx, installed = FALSE, package = package)
  if (is.null(manifest_path) || !nzchar(manifest_path)) {
    manifest_path <- file.path(dirname(output_dir), "manifest.json")
  }
  jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE)

  if (length(failures) > 0) {
    stop(
      "Artifact build failed:\n",
      paste0(" - ", failures, collapse = "\n"),
      call. = FALSE
    )
  }

  message("Wrote artifacts to ", output_dir)
  message("Wrote manifest: ", manifest_path)

  invisible(list(
    artifact_dir = output_dir,
    manifest = manifest,
    manifest_path = manifest_path
  ))
}

# Folder-backed implementation (unexported).
build_folder_outputs_impl <- function(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL,
  force_prep = FALSE,
  only_missing = FALSE
) {
  if (isTRUE(install_deps)) {
    old_opts <- options(
      replicateEverything.install_dependencies = TRUE,
      replicateEverything.install_stata_deps = TRUE
    )
    on.exit(
      options(
        replicateEverything.install_dependencies = old_opts[[
          "replicateEverything.install_dependencies"
        ]],
        replicateEverything.install_stata_deps = old_opts[[
          "replicateEverything.install_stata_deps"
        ]]
      ),
      add = TRUE
    )
  }
  study_root <- resolve_study_location(location)
  meta <- read_study_replication_yaml(study_root)
  if (is.null(meta)) {
    stop("Missing replication.yml in ", study_root, call. = FALSE)
  }

  paper <- meta$paper
  if (is.null(paper$doi) || !nzchar(as.character(paper$doi[[1]]))) {
    handle <- paper$study_handle %||% NULL
    if (is.null(handle) || !nzchar(as.character(handle[[1]]))) {
      stop("paper.doi or paper.study_handle is required in replication.yml", call. = FALSE)
    }
    doi <- as.character(handle[[1]])
  } else {
    doi <- normalize_doi(paper$doi)
  }
  folder <- doi_to_registry_folder(doi)

  if (!is.null(meta$paper$extends %||% meta$extends)) {
    meta <- merge_extended_study_meta(
      meta,
      paper_context(doi, folder = folder)
    )
  }

  if (is.null(registry_root) || !nzchar(registry_root)) {
    registry_root <- getOption("replicateEverything.registry_root", NULL)
  }

  display_reps <- folder_display_replications(meta)
  if (study_has_extension(meta)) {
    display_reps <- display_reps[vapply(display_reps, function(rep) {
      code_rel <- as.character(rep$code[[1]] %||% "")
      nzchar(code_rel) && file.exists(file.path(study_root, code_rel))
    }, logical(1))]
  }
  if (!is.null(ids)) {
    display_reps <- display_reps[vapply(display_reps, function(x) {
      x$id %in% ids
    }, logical(1))]
    missing_ids <- setdiff(ids, vapply(display_reps, function(x) x$id, character(1)))
    if (length(missing_ids)) {
      stop(
        "Unknown replication id(s): ", paste(missing_ids, collapse = ", "),
        call. = FALSE
      )
    }
  }

  display_reps <- filter_replications_only_missing(
    display_reps,
    doi,
    folder = folder,
    only_missing = only_missing,
    study_root = study_root
  )

  artifact_dir <- file.path(study_root, "outputs")
  dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)

  if (length(display_reps) == 0) {
    if (isTRUE(only_missing)) {
      message("All artifacts present; skipping build.")
      return(invisible(list(
        artifact_dir = artifact_dir,
        manifest = list(replications = list()),
        manifest_path = file.path(artifact_dir, "manifest.json")
      )))
    }
    stop("No figure/table replications to build.", call. = FALSE)
  }

  run_opts <- folder_study_run_options(study_root, meta, registry_root = registry_root)
  old_opts <- options(run_opts)
  on.exit(options(old_opts), add = TRUE)

  ctx <- paper_context(doi, folder = folder)
  # Caller already resolved the study repo; pin it so prep/display do not fall
  # back to getwd()-relative lookup (e.g. tests/testthat during testthat runs).
  ctx$local_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  prep_steps <- prep_steps_for_build(
    meta,
    if (is.null(ids)) NULL else display_reps
  )
  prep_result <- run_build_prep_steps(
    meta,
    ctx,
    doi,
    prep_steps,
    install_deps = install_deps,
    force = force_prep,
    study_root = study_root
  )

  display_result <- build_display_artifact_entries(
    display_reps,
    doi = doi,
    artifact_dir = artifact_dir,
    folder = folder,
    install_deps = install_deps,
    study_root = study_root
  )

  failures <- c(prep_result$failures, display_result$failures)

  manifest <- c(
    list(
      generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      folder = folder,
      doi = doi,
      prep = prep_result$statuses,
      replications = display_result$manifest
    ),
    folder_manifest_metadata(study_root, meta)
  )

  manifest_path <- file.path(artifact_dir, "manifest.json")
  jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE)

  if (length(failures) > 0) {
    stop(
      "Artifact build failed:\n",
      paste0(" - ", failures, collapse = "\n"),
      call. = FALSE
    )
  }

  message("Wrote artifacts to ", artifact_dir)
  message("Wrote manifest: ", manifest_path)

  invisible(list(
    artifact_dir = artifact_dir,
    manifest = manifest,
    manifest_path = manifest_path
  ))
}

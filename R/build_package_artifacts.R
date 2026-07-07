#' Build display artifacts for a package-backed study
#'
#' Runs pipeline prep steps from the package `replication.yml`, then builds
#' every registered table and figure into `inst/report/artifacts/` (or
#' `output_dir` when set). Study packages can delegate from `build_report()`.
#'
#' @param package Character name of the installed study package.
#' @param install_deps Logical. Install missing CRAN dependencies when `TRUE`.
#' @param ids Optional character vector of replication ids to build.
#' @param output_dir Optional output directory. Defaults to
#'   `inst/report/artifacts/` under the package source tree.
#' @param force_prep Logical. Re-run prep steps even when outputs already exist.
#' @return Invisibly, a list with `artifact_dir`, `manifest`, and `manifest_path`.
#'
#' @examples
#' \dontrun{
#' build_package_artifacts("rep1371journalpone0278337", install_deps = TRUE)
#' }
#'
#' @export
build_package_artifacts <- function(
  package,
  install_deps = TRUE,
  ids = NULL,
  output_dir = NULL,
  force_prep = FALSE
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
  pkg_root <- package_source_root(package)
  if (is.null(output_dir) || !nzchar(output_dir)) {
    if (is.null(pkg_root)) {
      stop("Could not resolve package source root for ", package, call. = FALSE)
    }
    output_dir <- file.path(pkg_root, "inst", "report", "artifacts")
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

  if (length(display_reps) == 0) {
    stop("No figure/table replications to build.", call. = FALSE)
  }

  ctx <- paper_context(doi, folder = folder)
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

  manifest_path <- file.path(dirname(output_dir), "manifest.json")
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

#' Build display artifacts for a folder-backed study
#'
#' Runs pipeline prep steps from `replication.yml` when present, then every
#' registered table and figure, saves formatted outputs under `artifacts/`, and
#' writes `artifacts/manifest.json`. Intended to be run from the study
#' repository root (or pass the path explicitly).
#'
#' Registry papers use `registry/scripts/build_artifacts.R` instead; folder-backed
#' studies keep materials in their own repository.
#'
#' @param location Local study path or GitHub address. Defaults to `"."` when
#'   the working directory contains `replication.yml`.
#' @param install_deps Logical. Install missing CRAN dependencies when `TRUE`.
#' @param ids Optional character vector of replication ids to build. When
#'   `NULL`, builds every figure and table in `replication.yml`.
#' @param registry_root Optional registry checkout path for monorepo dev.
#' @param force_prep Logical. Re-run prep steps even when outputs already exist.
#' @return Invisibly, a list with `artifact_dir`, `manifest`, and per-id status.
#'
#' @examples
#' \dontrun{
#' build_study_artifacts(".", install_deps = TRUE)
#' }
#'
#' @export
build_study_artifacts <- function(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL,
  force_prep = FALSE
) {
  study_root <- resolve_study_location(location)
  meta <- read_study_replication_yaml(study_root)
  if (is.null(meta)) {
    stop("Missing replication.yml in ", study_root, call. = FALSE)
  }

  paper <- meta$paper
  if (is.null(paper$doi) || !nzchar(as.character(paper$doi[[1]]))) {
    stop("paper.doi is required in replication.yml", call. = FALSE)
  }

  doi <- normalize_doi(paper$doi)
  folder <- doi_to_registry_folder(doi)

  if (is.null(registry_root) || !nzchar(registry_root)) {
    registry_root <- getOption("replicateEverything.registry_root", NULL)
  }

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

  artifact_dir <- file.path(study_root, "artifacts")
  dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)

  run_opts <- folder_study_run_options(study_root, meta, registry_root = registry_root)
  old_opts <- options(run_opts)
  on.exit(options(old_opts), add = TRUE)

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

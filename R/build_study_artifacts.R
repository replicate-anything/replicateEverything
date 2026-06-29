#' Build display artifacts for a folder-backed study
#'
#' Runs every registered table and figure, saves formatted outputs under
#' `artifacts/`, and writes `artifacts/manifest.json`. Intended to be run from
#' the study repository root (or pass the path explicitly).
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
#' @return Invisibly, a list with `artifact_dir`, `manifest`, and per-id status.
#' @export
build_study_artifacts <- function(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL
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

  manifest <- list(
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    folder = folder,
    doi = doi,
    study_path = study_root,
    replications = list()
  )

  failures <- character(0)

  for (rep in display_reps) {
    rep_id <- rep$id
    message("Building ", rep_id, " ...")

    status <- tryCatch({
      result <- render_replication(
        doi,
        rep_id,
        install_deps = install_deps,
        folder = folder
      )
      out <- save_artifact(
        result,
        artifact_dir,
        doi = doi,
        folder = folder,
        install_deps = install_deps
      )
      out_file <- file.path(artifact_dir, basename(out))
      if (!file.exists(out_file)) {
        stop("Artifact file was not created: ", out_file)
      }
      validate_artifact(doi, rep_id)
      list(
        status = "ok",
        artifact = file.path("artifacts", basename(out)),
        format = switch(
          tools::file_ext(out_file),
          html = "html",
          png = "ggplot",
          rds = "rds",
          result$format
        )
      )
    }, error = function(e) {
      failures <<- c(failures, paste0(rep_id, ": ", conditionMessage(e)))
      list(status = "error", message = conditionMessage(e))
    })

    manifest$replications[[rep_id]] <- status
  }

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

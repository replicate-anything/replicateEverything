#' Add a folder-backed study to the replication registry
#'
#' Validates a folder-backed study with [check_folder_replication()], writes
#' or reuses `registry/replication.yml` and `registry/index.csv` in the study
#' repo, then copies them into the registry checkout via [sync_folder_paper()].
#'
#' Equivalent to [prepare_folder_paper()] followed by [sync_folder_paper()] when
#' you already have a local registry checkout. If you only need the stub files,
#' use [prepare_folder_paper()] and copy them manually.
#'
#' @param location Local study path or GitHub address. Defaults to `"."`.
#' @param full_replication If `TRUE`, also run every table and figure live.
#' @param registry_root Path to the registry repository root. Defaults to
#'   `getOption("replicateEverything.registry_root")`.
#' @param dry_run If `TRUE`, run checks only; do not write registry files.
#' @param build_artifacts If `TRUE`, run [build_study_artifacts()] before checks.
#' @param install_deps Passed to [build_study_artifacts()].
#' @return Invisibly, the result of [check_folder_replication()], with
#'   `stub_path` and `index_updated` when registration succeeds.
#' @keywords internal
add_folder_paper <- function(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE,
  build_artifacts = FALSE,
  install_deps = TRUE
) {
  if (isTRUE(build_artifacts)) {
    build_study_artifacts(
      location = location,
      install_deps = install_deps,
      registry_root = registry_root
    )
  }

  result <- check_folder_replication(
    location,
    full_replication = full_replication,
    registry_root = registry_root
  )

  if (!isTRUE(result$ok)) {
    message("Folder study validation failed:")
    failed <- result$checks[!result$checks$passed, , drop = FALSE]
    for (i in seq_len(nrow(failed))) {
      message("  [FAIL] ", failed$check[i], ": ", failed$message[i])
    }
    message(
      "\nSee vignette('folder-replication-checklist', package = 'replicateEverything') ",
      "for requirements."
    )
    return(invisible(result))
  }

  message("All checks passed (", nrow(result$checks), " items).")

  if (isTRUE(dry_run)) {
    message("dry_run = TRUE: registry not modified.")
    return(invisible(result))
  }

  study_root <- result$study_path
  local_stub <- file.path(study_root, "registry", "replication.yml")
  if (!file.exists(local_stub)) {
    write_folder_registry_stub(location)
  }

  synced <- sync_folder_paper(location, registry_root = registry_root)

  result$stub_path <- synced$stub_path
  result$index_updated <- synced$index_updated
  result$folder <- synced$folder
  result$registry_stub_path <- local_stub
  result$registry_index_path <- file.path(study_root, "registry", "index.csv")
  invisible(structure(result, class = c("folder_replication_check", "replication_check", "list")))
}

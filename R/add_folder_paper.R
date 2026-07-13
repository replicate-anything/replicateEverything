#' Add a folder-backed study to the replication registry (maintainer)
#'
#' Validates a folder-backed study with [check_replication()], ensures
#' registry handoff files exist (via [write_study_registry_stub()] when missing),
#' then installs the stub in a registry checkout via [sync_study_to_registry()].
#'
#' Contributors should run [prepare_study_for_registry()] and open a pull request.
#' Maintainers use this function (or `sync_study_to_registry()` directly) from a
#' local registry checkout.
#'
#' @param location Local study path or GitHub address. Defaults to `"."`.
#' @param full_replication If `TRUE`, also run every table and figure live.
#' @param registry_root Path to the registry repository root. Defaults to
#'   `getOption("replicateEverything.registry_root")`.
#' @param dry_run If `TRUE`, run checks only; do not write registry files.
#' @param build_artifacts If `TRUE`, run [build_study_outputs()] before checks.
#' @param install_deps Passed to [build_study_outputs()].
#' @param audit If `TRUE`, run [audit_everything()] for this study after sync.
#' @return Invisibly, the result of [check_replication()], with
#'   `stub_path` and `index_updated` when registration succeeds.
#' @keywords internal
add_folder_paper <- function(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE,
  build_artifacts = FALSE,
  install_deps = TRUE,
  audit = FALSE
) {
  if (isTRUE(build_artifacts)) {
    build_study_outputs(
      location = location,
      install_deps = install_deps,
      registry_root = registry_root
    )
  }

  result <- check_replication(
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
  paths <- study_registry_handoff_paths(study_root, kind = "folder")
  if (!file.exists(paths$stub_path)) {
    write_study_registry_stub(study_root)
  }

  synced <- sync_study_to_registry(
    study_root,
    registry_root = registry_root,
    audit = audit
  )

  result$stub_path <- synced$stub_path
  result$index_updated <- synced$index_updated
  result$folder <- synced$folder
  result$registry_stub_path <- paths$stub_path
  result$registry_index_path <- paths$index_path
  invisible(structure(result, class = c("folder_replication_check", "replication_check", "list")))
}

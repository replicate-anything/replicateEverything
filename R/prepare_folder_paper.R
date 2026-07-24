#' Build outputs and validate a study (contributor)
#'
#' Optionally bakes display artifacts with [build_study_outputs()], then runs
#' [check_replication()]. On success the study is ready for a maintainer to
#' register it with [sync_study_to_registry()] (stub written only into the
#' central registry repository).
#'
#' @param location Study repo path or GitHub address. Defaults to `"."` — the
#'   current working directory, i.e. the same study `doi = "local"` resolves
#'   to for [list_replications()] / [run_replication()] / [get_code()].
#' @param build_artifacts If `TRUE`, build precomputed outputs first.
#' @param install_deps Passed to the build function.
#' @param full_replication If `TRUE`, also run every table and figure live.
#' @param registry_root Optional registry checkout (passed to build/check helpers).
#' @return Invisibly, a checklist result (`folder_replication_check` or
#'   `package_replication_check`).
#'
#' @examples
#' \dontrun{
#' # setwd() to the study repo (or open its RStudio project) first.
#' setwd("path/to/rep-my-study")
#'
#' # Manual smoke check before the full contributor checklist — no
#' # registry required:
#' list_replications("local")
#' describe_study_dag("local")
#' run_replication("local", "tab_1")  # one light step
#'
#' check_and_bake_study(".")
#' }
#'
#' @export
check_and_bake_study <- function(
  location = ".",
  build_artifacts = TRUE,
  install_deps = TRUE,
  full_replication = FALSE,
  registry_root = NULL
) {
  study_root <- resolve_study_root(location)
  kind <- detect_study_kind_from_root(study_root)

  if (isTRUE(build_artifacts)) {
    build_study_outputs(
      location = study_root,
      install_deps = install_deps,
      registry_root = registry_root
    )
  }

  result <- check_replication(
    study_root,
    full_replication = full_replication,
    registry_root = registry_root
  )

  if (!isTRUE(result$ok)) {
    message("Study validation failed:")
    failed <- result$checks[!result$checks$passed, , drop = FALSE]
    for (i in seq_len(nrow(failed))) {
      message("  [FAIL] ", failed$check[i], ": ", failed$message[i])
    }
    vignette <- if (identical(kind, "package")) {
      "package-replication-checklist"
    } else {
      "folder-replication-checklist"
    }
    message(
      "\nSee vignette('", vignette, "', package = 'replicateEverything') ",
      "for requirements."
    )
    return(invisible(result))
  }

  message("All checks passed (", nrow(result$checks), " items).")
  message(
    "A registry maintainer can register this study with sync_study_to_registry() ",
    "(stub is written only into the registry repository)."
  )

  result$folder <- registry_folder_from_paper(
    read_study_meta_from_root(study_root, kind = kind)$paper
  )
  result$study_kind <- kind
  cls <- if (identical(kind, "package")) {
    c("package_replication_check", "replication_check", "list")
  } else {
    c("folder_replication_check", "replication_check", "list")
  }
  invisible(structure(result, class = cls))
}

#' Sync a study into the registry repository (maintainer)
#'
#' Builds a lightweight registry stub from the study's root `replication.yml`
#' (via [build_registry_stub_from_meta()]) and writes it to
#' `studies/<folder>.yml` in a registry checkout, then rebuilds `index.csv`
#' via [build_registry_index()].
#'
#' Stub and index files belong in the **registry** repository only — not in the
#' study repo.
#'
#' @param location Study repo path or GitHub address. Defaults to `"."`.
#' @param registry_root Path to the registry repository root. Defaults to
#'   `getOption("replicateEverything.registry_root")`.
#' @param audit If `TRUE`, run [audit_everything()] for this study after sync.
#' @param patience Seconds per replication when `audit = TRUE`.
#' @param install_deps Passed to [audit_everything()] when `audit = TRUE`.
#' @param verbose Passed to [audit_everything()] when `audit = TRUE`.
#' @return Invisibly, a list with `stub_path`, `index_updated`, `folder`, and
#'   optional `audit`.
#'
#' @examples
#' \dontrun{
#' options(replicateEverything.registry_root = "../registry")
#' sync_study_to_registry(".")
#' }
#'
#' @export
sync_study_to_registry <- function(
  location = ".",
  registry_root = NULL,
  audit = FALSE,
  patience = 20,
  install_deps = FALSE,
  verbose = TRUE
) {
  study_root <- resolve_study_root(location)
  kind <- detect_study_kind_from_root(study_root)
  meta <- read_study_meta_from_root(study_root, kind = kind)

  if (is.null(registry_root) || !nzchar(registry_root)) {
    registry_root <- getOption("replicateEverything.registry_root", NULL)
  }
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    stop(
      "registry_root not found. Pass the path to the registry repository or set ",
      "options(replicateEverything.registry_root = ...).",
      call. = FALSE
    )
  }

  folder <- registry_folder_from_paper(meta$paper)
  studies_dir <- registry_studies_dir(registry_root)
  dir.create(studies_dir, recursive = TRUE, showWarnings = FALSE)
  stub_path <- file.path(studies_dir, paste0(folder, ".yml"))

  stub <- build_registry_stub_from_meta(meta, study_root, kind = kind)
  materials <- if (identical(kind, "package")) {
    "package-backed"
  } else {
    "folder-backed"
  }
  header <- c(
    paste0("# Lightweight registry stub for a ", materials, " study."),
    paste0("# Generated from study replication.yml by sync_study_to_registry()."),
    paste0("# Registry folder: ", folder),
    ""
  )
  writeLines(c(header, yaml::as.yaml(stub)), stub_path, useBytes = TRUE)

  legacy_dir <- file.path(studies_dir, folder)
  if (dir.exists(legacy_dir)) {
    unlink(legacy_dir, recursive = TRUE)
  }

  index_updated <- build_registry_index(registry_root)
  row <- registry_index_row_from_meta(meta, study_root = study_root)

  message("Synced registry stub: ", stub_path)
  message("Updated index: ", index_updated$index_path)

  audit_out <- NULL
  if (isTRUE(audit)) {
    doi <- as.character(row$doi[[1]] %||% "")
    handle <- as.character(row$handle[[1]] %||% folder)
    audit_target <- if (nzchar(trimws(doi))) {
      doi
    } else {
      handle
    }
    message("Running audit_everything for ", audit_target)
    audit_out <- audit_everything(
      patience = patience,
      dois = audit_target,
      install_deps = install_deps,
      verbose = verbose,
      registry_root = registry_root
    )
  }

  invisible(list(
    stub_path = stub_path,
    index_updated = index_updated$index_path,
    folder = folder,
    kind = kind,
    audit = audit_out
  ))
}

#' Validate then sync a study into the registry (maintainer)
#'
#' Runs [check_and_bake_study()] then [sync_study_to_registry()]. Use when a
#' maintainer has a study checkout and a local registry checkout.
#'
#' @inheritParams check_and_bake_study
#' @param dry_run If `TRUE`, run checks only; do not write registry files.
#' @param audit If `TRUE`, run [audit_everything()] for this study after sync.
#' @return Invisibly, the checklist result; when registration succeeds, also
#'   includes `stub_path` and `index_updated`.
#' @export
register_study <- function(
  location = ".",
  build_artifacts = FALSE,
  install_deps = TRUE,
  full_replication = FALSE,
  registry_root = NULL,
  dry_run = FALSE,
  audit = FALSE
) {
  result <- check_and_bake_study(
    location = location,
    build_artifacts = build_artifacts,
    install_deps = install_deps,
    full_replication = full_replication,
    registry_root = registry_root
  )

  if (!isTRUE(result$ok)) {
    return(invisible(result))
  }

  if (isTRUE(dry_run)) {
    message("dry_run = TRUE: registry not modified.")
    return(invisible(result))
  }

  study_root <- result$study_path %||% result$package_path
  synced <- sync_study_to_registry(
    study_root,
    registry_root = registry_root,
    audit = audit
  )

  result$stub_path <- synced$stub_path
  result$index_updated <- synced$index_updated
  result$folder <- synced$folder
  invisible(result)
}

#' Refresh the registry index and optionally rerun the full audit (maintainer)
#'
#' Recompiles `index.csv` from all `studies/*.yml` stubs, then optionally runs
#' [audit_everything()] across the registry.
#'
#' @param registry_root Path to the registry repository root.
#' @param audit If `TRUE`, run [audit_everything()] after rebuilding the index.
#' @param patience Seconds per replication when auditing.
#' @param install_deps Passed to [audit_everything()].
#' @param verbose Passed to [audit_everything()].
#' @param substantive Passed to [audit_everything()].
#' @return Invisibly, a list with `index` and optional `audit`.
#' @export
#'
#' @examples
#' \dontrun{
#' options(replicateEverything.registry_root = "../registry")
#' refresh_registry(audit = TRUE)
#' }
refresh_registry <- function(
  registry_root = NULL,
  audit = TRUE,
  patience = 20,
  install_deps = FALSE,
  verbose = TRUE,
  substantive = TRUE
) {
  if (is.null(registry_root) || !nzchar(registry_root)) {
    registry_root <- getOption("replicateEverything.registry_root", NULL)
  }
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    stop(
      "registry_root not found. Pass the path to the registry repository or set ",
      "options(replicateEverything.registry_root = ...).",
      call. = FALSE
    )
  }

  index <- build_registry_index(registry_root)
  message("Rebuilt index: ", index$index_path, " (", index$n, " studies)")

  audit_out <- NULL
  if (isTRUE(audit)) {
    message("Running audit_everything across the registry")
    audit_out <- audit_everything(
      patience = patience,
      install_deps = install_deps,
      verbose = verbose,
      registry_root = registry_root,
      substantive = substantive
    )
  }

  invisible(list(index = index, audit = audit_out))
}

#' Prepare a study repository for registry handoff (contributor)
#'
#' Validates a folder- or package-backed study, then writes the short registry
#' yaml and one-row `index.csv` into the study repository:
#'
#' \itemize{
#'   \item Folder studies: `registry/replication.yml` and `registry/index.csv`
#'   \item Package studies: `inst/registry/replication.yml` and `inst/registry/index.csv`
#' }
#'
#' This is the **contributor** step. A registry maintainer installs those files
#' with [sync_study_to_registry()] and refreshes the central index with
#' [refresh_registry()].
#'
#' Runs [build_study_artifacts()] or [build_package_artifacts()] (optional),
#' then [check_folder_replication()] or [check_package_replication()], and on
#' success writes and validates the registry stub via [write_study_registry_stub()].
#'
#' @param location Study repo path or GitHub address. Defaults to `"."`.
#' @param build_artifacts If `TRUE`, build precomputed outputs first.
#' @param install_deps Passed to the build function.
#' @param full_replication If `TRUE`, also run every table and figure live.
#' @param registry_root Optional registry checkout (passed to build/check helpers).
#' @return Invisibly, a checklist result with `registry_stub_path` and
#'   `registry_index_path` when successful.
#'
#' @examples
#' \dontrun{
#' prepare_study_for_registry(".")
#' }
#'
#' @export
prepare_study_for_registry <- function(
  location = ".",
  build_artifacts = TRUE,
  install_deps = TRUE,
  full_replication = FALSE,
  registry_root = NULL
) {
  study_root <- resolve_study_root(location)
  kind <- detect_study_kind_from_root(study_root)

  if (isTRUE(build_artifacts)) {
    if (identical(kind, "package")) {
      build_package_artifacts(
        package = package_name_from_root(study_root),
        install_deps = install_deps
      )
    } else {
      build_study_artifacts(
        location = study_root,
        install_deps = install_deps,
        registry_root = registry_root
      )
    }
  }

  result <- if (identical(kind, "package")) {
    check_package_replication(
      study_root,
      full_replication = full_replication
    )
  } else {
    check_folder_replication(
      study_root,
      full_replication = full_replication,
      registry_root = registry_root
    )
  }

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

  written <- write_study_registry_stub(study_root)
  message(
    "All checks passed (", nrow(result$checks), " items). ",
    "Registry handoff written under ", written$stub_dir
  )
  message(
    "A registry maintainer can install this with sync_study_to_registry() ",
    "and refresh_registry()."
  )

  result$registry_stub_path <- written$stub_path
  result$registry_index_path <- written$index_path
  result$folder <- written$folder
  result$study_kind <- kind
  cls <- if (identical(kind, "package")) {
    c("package_replication_check", "replication_check", "list")
  } else {
    c("folder_replication_check", "replication_check", "list")
  }
  invisible(structure(result, class = cls))
}

#' @describeIn prepare_study_for_registry Deprecated alias for folder studies.
#' @export
prepare_folder_paper <- function(
  location = ".",
  build_artifacts = TRUE,
  install_deps = TRUE,
  full_replication = FALSE,
  registry_root = NULL
) {
  .Deprecated("prepare_study_for_registry")
  prepare_study_for_registry(
    location = location,
    build_artifacts = build_artifacts,
    install_deps = install_deps,
    full_replication = full_replication,
    registry_root = registry_root
  )
}

#' Sync a prepared study into the registry repository (maintainer)
#'
#' Reads the short registry yaml from the study repository (`registry/` or
#' `inst/registry/`), copies it to `studies/<folder>.yml` in a registry
#' checkout, and rebuilds `index.csv` via [build_registry_index()].
#'
#' This is a **maintainer** function. Contributors should run
#' [prepare_study_for_registry()] and open a pull request; maintainers run this
#' (or [refresh_registry()]) from a local registry checkout.
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
  paths <- study_registry_handoff_paths(study_root, kind = kind)
  local_stub <- paths$stub_path
  local_index <- paths$index_path

  if (!file.exists(local_stub)) {
    stop(
      "No registry handoff yaml at ", local_stub, ". ",
      "Run prepare_study_for_registry() in the study repository first.",
      call. = FALSE
    )
  }
  if (!file.exists(local_index)) {
    stop(
      "No registry handoff index at ", local_index, ". ",
      "Run prepare_study_for_registry() in the study repository first.",
      call. = FALSE
    )
  }

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

  row <- utils::read.csv(local_index, stringsAsFactors = FALSE)
  if (nrow(row) != 1L) {
    stop("Study registry/index.csv must contain exactly one row.", call. = FALSE)
  }
  folder <- row$folder[[1]]

  studies_dir <- registry_studies_dir(registry_root)
  dir.create(studies_dir, recursive = TRUE, showWarnings = FALSE)
  stub_path <- file.path(studies_dir, paste0(folder, ".yml"))
  file.copy(local_stub, stub_path, overwrite = TRUE)
  legacy_dir <- file.path(studies_dir, folder)
  if (dir.exists(legacy_dir)) {
    unlink(legacy_dir, recursive = TRUE)
  }

  index_updated <- build_registry_index(registry_root)

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

#' @describeIn sync_study_to_registry Deprecated alias.
#' @export
sync_folder_paper <- function(location = ".", registry_root = NULL) {
  .Deprecated("sync_study_to_registry")
  sync_study_to_registry(location = location, registry_root = registry_root)
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

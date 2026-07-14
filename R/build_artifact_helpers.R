#' Filter replication entries to those without precomputed artifacts
#'
#' @param display_reps List of replication entries.
#' @param doi Paper DOI or lookup key.
#' @param folder Optional registry folder name.
#' @param repo Optional repository slug.
#' @param only_missing When \code{TRUE}, keep only entries where
#'   \code{\link{artifact_available}()} is \code{FALSE}.
#' @param study_root Optional local study root for direct file checks.
#' @keywords internal
replication_artifact_exists <- function(
  rep,
  doi,
  folder = NULL,
  repo = NULL,
  study_root = NULL
) {
  if (!is.null(study_root) && nzchar(study_root)) {
    for (rel in study_artifact_rel_candidates(rep)) {
      if (file.exists(file.path(study_root, rel))) {
        return(TRUE)
      }
    }
  }
  artifact_available(doi, rep$id, repo = repo, folder = folder)
}

#' @rdname filter_replications_only_missing
filter_replications_only_missing <- function(
  display_reps,
  doi,
  folder = NULL,
  repo = NULL,
  only_missing = FALSE,
  study_root = NULL
) {
  if (!isTRUE(only_missing)) {
    return(display_reps)
  }
  display_reps[vapply(display_reps, function(rep) {
    !replication_artifact_exists(
      rep,
      doi,
      folder = folder,
      repo = repo,
      study_root = study_root
    )
  }, logical(1))]
}

#' Build table and figure artifacts into a directory
#'
#' @param display_reps List of replication entries.
#' @param doi Paper DOI.
#' @param artifact_dir Output directory.
#' @param folder Optional registry folder name.
#' @param install_deps Passed to runners.
#' @param study_root Optional root for portable error messages.
#' @keywords internal
build_display_artifact_entries <- function(
  display_reps,
  doi,
  artifact_dir,
  folder = NULL,
  install_deps = FALSE,
  study_root = NULL
) {
  manifest <- list()
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
      rel_out <- study_artifact_rel_path(rep)
      manifest_artifact <- if (nzchar(rel_out)) {
        rel_out
      } else {
        file.path("outputs", basename(out))
      }
      list(
        status = "ok",
        artifact = manifest_artifact,
        format = switch(
          tools::file_ext(out_file),
          html = "html",
          png = "ggplot",
          rds = "rds",
          result$format
        )
      )
    }, error = function(e) {
      msg <- if (!is.null(study_root) && nzchar(study_root)) {
        portable_path_in_text(conditionMessage(e), study_root)
      } else {
        conditionMessage(e)
      }
      failures <<- c(failures, paste0(rep_id, ": ", msg))
      list(status = "error", message = msg)
    })

    manifest[[rep_id]] <- status
  }

  list(manifest = manifest, failures = failures)
}

#' Installed package source tree
#' @keywords internal
package_source_root <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(NULL)
  }
  root <- getNamespaceInfo(asNamespace(package), "path")
  if (length(root) == 1L && nzchar(root) && dir.exists(root)) {
    return(normalizePath(root, winslash = "/", mustWork = FALSE))
  }
  NULL
}

#' Read replication metadata from an installed study package
#' @keywords internal
read_package_replication_meta <- function(package) {
  if (exists("replication_meta", mode = "function", envir = asNamespace(package))) {
    return(get("replication_meta", envir = asNamespace(package))())
  }
  yml <- system.file("replication.yml", package = package)
  if (!nzchar(yml)) {
    stop("Package ", package, " has no replication.yml.", call. = FALSE)
  }
  yaml::read_yaml(yml)
}

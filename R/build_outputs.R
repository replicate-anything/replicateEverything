#' Build a single precomputed output
#'
#' @inheritParams validate_outputs
#' @param install_deps Logical. Install missing dependencies when `TRUE`.
#' @param only_missing Logical. When `TRUE`, skip when the artifact already exists.
#' @param force_prep Logical. Re-run prep steps even when outputs already exist.
#' @return Invisibly \code{TRUE} on success.
#' @keywords internal
build_single_output <- function(
  doi,
  what,
  only_missing = FALSE,
  install_deps = TRUE,
  repo = NULL,
  folder = NULL,
  registry_root = NULL,
  force_prep = FALSE,
  language = NULL
) {
  if (isTRUE(only_missing)) {
    meta <- get_replication_meta(doi, repo = repo, folder = folder)
    rep <- find_replication_entry(meta, what, language = language)
    ctx <- paper_context(doi, repo = repo, folder = folder)
    study_root <- ctx$local_root
    if (!is_package_replication(meta) && is.null(study_root)) {
      study_root <- NULL
    }
    if (is_package_replication(meta)) {
      pkg <- as.character(meta$paper$package[[1]])
      study_root <- package_source_root(pkg)
    }
    if (replication_artifact_exists(
      rep,
      doi,
      folder = folder,
      repo = repo,
      study_root = study_root
    )) {
      message("Artifact already present for ", what, "; skipping build.")
      return(invisible(TRUE))
    }
  }

  meta <- get_replication_meta(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    build_study_outputs(
      pkg,
      install_deps = install_deps,
      ids = what,
      only_missing = only_missing,
      force_prep = force_prep
    )
    return(invisible(TRUE))
  }

  ctx <- paper_context(doi, repo = repo, folder = folder)
  if (is.null(ctx$local_root)) {
    stop(
      "No local study repository found for ", doi,
      ". Clone the study repo or pass location = ... to build_outputs().",
      call. = FALSE
    )
  }

  build_study_outputs(
    ctx$local_root,
    install_deps = install_deps,
    ids = what,
    registry_root = registry_root,
    only_missing = only_missing,
    force_prep = force_prep
  )
  invisible(TRUE)
}

#' Build all precomputed outputs for one paper
#'
#' @param doi Character. DOI of the paper.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name.
#' @inheritParams build_single_output
#' @return Invisibly \code{TRUE} on success.
#' @keywords internal
build_paper_outputs <- function(
  doi,
  only_missing = FALSE,
  install_deps = TRUE,
  repo = NULL,
  folder = NULL,
  registry_root = NULL,
  force_prep = FALSE
) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    build_study_outputs(
      pkg,
      install_deps = install_deps,
      only_missing = only_missing,
      force_prep = force_prep
    )
    return(invisible(TRUE))
  }

  ctx <- paper_context(doi, repo = repo, folder = folder)
  if (is.null(ctx$local_root)) {
    stop(
      "No local study repository found for ", doi,
      ". Clone the study repo or pass location = ... to build_outputs().",
      call. = FALSE
    )
  }

  build_study_outputs(
    ctx$local_root,
    install_deps = install_deps,
    registry_root = registry_root,
    only_missing = only_missing,
    force_prep = force_prep
  )
  invisible(TRUE)
}

#' Build precomputed outputs for every study in a registry checkout
#'
#' @param registry_root Path to the registry repository.
#' @param folders Optional character vector of study folder names.
#' @inheritParams build_single_output
#' @return Invisibly \code{TRUE} if every build succeeds.
#' @keywords internal
build_registry_outputs <- function(
  registry_root = NULL,
  folders = NULL,
  only_missing = FALSE,
  install_deps = TRUE,
  force_prep = FALSE
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

  studies_dir <- registry_studies_dir(registry_root)
  study_folders <- if (!is.null(folders)) {
    sub("^studies/", "", sub("^papers/", "", sub("\\.yml$", "", basename(folders))))
  } else {
    yml_files <- list.files(studies_dir, pattern = "\\.yml$", full.names = FALSE)
    sub("\\.yml$", "", yml_files)
  }

  failures <- character(0)
  old_registry <- getOption("replicateEverything.registry_root", NULL)
  options(replicateEverything.registry_root = registry_root)
  on.exit(options(replicateEverything.registry_root = old_registry), add = TRUE)

  for (folder in study_folders) {
    yml_path <- file.path(studies_dir, paste0(folder, ".yml"))
    if (!file.exists(yml_path)) {
      yml_path <- file.path(studies_dir, folder, "replication.yml")
    }
    if (!file.exists(yml_path)) {
      next
    }

    meta <- yaml::read_yaml(yml_path)
    lookup <- study_lookup_from_paper(meta$paper, folder = folder)

    if (is_package_replication(meta)) {
      message("Building ", folder, " (package-backed) ...")
      tryCatch(
        build_study_outputs(
          meta$paper$package,
          install_deps = install_deps,
          only_missing = only_missing,
          force_prep = force_prep
        ),
        error = function(e) {
          failures <<- c(failures, paste0(folder, ": ", conditionMessage(e)))
        }
      )
      next
    }

    ctx <- paper_context(lookup, folder = folder)
    if (isTRUE(ctx$is_folder_study)) {
      if (is.null(ctx$local_root) || !dir.exists(ctx$local_root)) {
        message(
          "Skipping ", folder,
          " (folder-backed; no local study repo)."
        )
        next
      }
      message(
        "Building ", folder, " (folder-backed; study repo ",
        ctx$materials_repo, ") ..."
      )
      tryCatch(
        build_study_outputs(
          ctx$local_root,
          install_deps = install_deps,
          registry_root = registry_root,
          only_missing = only_missing,
          force_prep = force_prep
        ),
        error = function(e) {
          failures <<- c(failures, paste0(folder, ": ", conditionMessage(e)))
        }
      )
    } else {
      message(
        "Skipping ", folder,
        " (registry-local; use scripts/build_artifacts.R)."
      )
    }
  }

  if (length(failures) > 0) {
    stop(
      "Artifact build failed:\n",
      paste0(" - ", failures, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Build precomputed outputs
#'
#' Maintainer helper: runs registered table and figure replications and writes
#' formatted outputs to disk (folder-backed studies: study repo \code{outputs/};
#' package-backed: installed package report outputs). Mirrors [validate_outputs()]
#' dispatch for registry-wide or single-study builds.
#'
#' @param doi Character DOI, or \code{"everywhere"} to build every registry
#'   study. Ignored when \code{location} is set.
#' @param what Replication id, or \code{"everything"} (default when \code{doi}
#'   or \code{location} is set) to build every table and figure in scope.
#' @param location Local study path or GitHub address. When set, builds outputs
#'   for that study repository (equivalent to passing its DOI with
#'   \code{what = "everything"}).
#' @param registry_root Optional registry checkout for monorepo dev. Used with
#'   \code{doi = "everywhere"} or \code{location}.
#' @param folders Optional character vector of registry folder names when
#'   \code{doi = "everywhere"}. Defaults to all \code{studies/*.yml} stubs.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name (for a single \code{doi}).
#' @param language Optional engine language for multi-engine replications.
#' @param install_deps Logical. Install missing dependencies when \code{TRUE}.
#' @param only_missing Logical. When \code{TRUE}, skip replications whose
#'   artifacts already exist (see [artifact_available()]).
#' @param force_prep Logical. Re-run prep steps even when outputs already exist.
#' @return Invisibly \code{TRUE} on success.
#' @seealso [validate_outputs()], [build_study_outputs()]
#' @export
#'
#' @examples
#' \dontrun{
#' build_outputs(doi = "10.1177/00491241211036161", what = "fig_1")
#' build_outputs(doi = "10.1177/00491241211036161", what = "everything")
#' build_outputs(location = ".")
#' build_outputs(doi = "10.1177/00491241211036161", what = "tab_1", only_missing = TRUE)
#' options(replicateEverything.registry_root = "../registry")
#' build_outputs(doi = "everywhere", what = "everything")
#' build_outputs(doi = "everywhere", folders = "10.1177_00491241211036161")
#' }
build_outputs <- function(
  doi = NULL,
  what = NULL,
  location = NULL,
  registry_root = NULL,
  folders = NULL,
  repo = NULL,
  folder = NULL,
  language = NULL,
  install_deps = TRUE,
  only_missing = FALSE,
  force_prep = FALSE
) {
  if (identical(doi, "everywhere")) {
    if (!is.null(what) && !identical(what, "everything")) {
      stop(
        'When doi = "everywhere", what must be "everything" or NULL.',
        call. = FALSE
      )
    }
    return(build_registry_outputs(
      registry_root = registry_root,
      folders = folders,
      only_missing = only_missing,
      install_deps = install_deps,
      force_prep = force_prep
    ))
  }

  if (!is.null(location)) {
    study_root <- resolve_study_root(location)
    meta <- read_study_replication_yaml(study_root)
    if (is.null(meta)) {
      stop("Missing replication.yml in ", study_root, call. = FALSE)
    }
    paper <- meta$paper
    study_doi <- study_lookup_from_paper(paper)
    study_folder <- if (!is.null(paper$doi) && nzchar(as.character(paper$doi[[1]] %||% ""))) {
      doi_to_registry_folder(study_doi)
    } else {
      registry_folder_from_paper(paper)
    }
    if (is.null(registry_root) || !nzchar(registry_root)) {
      registry_root <- getOption("replicateEverything.registry_root", NULL)
    }
    old_registry <- getOption("replicateEverything.registry_root", NULL)
    if (!is.null(registry_root) && nzchar(registry_root)) {
      options(replicateEverything.registry_root = registry_root)
      on.exit(options(replicateEverything.registry_root = old_registry), add = TRUE)
    }
    if (is.null(what) || identical(what, "everything")) {
      return(build_study_outputs(
        study_root,
        install_deps = install_deps,
        registry_root = registry_root,
        only_missing = only_missing,
        force_prep = force_prep
      ))
    }
    return(build_study_outputs(
      study_root,
      install_deps = install_deps,
      ids = what,
      registry_root = registry_root,
      only_missing = only_missing,
      force_prep = force_prep
    ))
  }

  if (is.null(doi)) {
    stop(
      'Provide doi, location, or doi = "everywhere".',
      call. = FALSE
    )
  }

  if (is.null(what) || identical(what, "everything")) {
    return(build_paper_outputs(
      doi,
      only_missing = only_missing,
      install_deps = install_deps,
      repo = repo,
      folder = folder,
      registry_root = registry_root,
      force_prep = force_prep
    ))
  }

  build_single_output(
    doi,
    what,
    only_missing = only_missing,
    install_deps = install_deps,
    repo = repo,
    folder = folder,
    registry_root = registry_root,
    force_prep = force_prep,
    language = language
  )
}

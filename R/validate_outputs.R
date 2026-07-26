#' Resolve the expected artifact path for a replication entry
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @param what Replication identifier.
#' @keywords internal
default_artifact_path <- function(rep, what) {
  if (identical(rep$type, "figure")) {
    return(paste0("outputs/", what, ".png"))
  }
  if (format_specified(rep)) {
    return(paste0("outputs/", what, ".html"))
  }
  paste0("outputs/", what, ".html")
}

#' Get the local artifact file path for a replication, if available
#'
#' @inheritParams render_replication
#' @return Character path or \code{NULL}.
#' @keywords internal
local_artifact_path <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  if (is_package_replication(meta)) {
    return(NULL)
  }

  rep <- find_replication_entry(meta, what, language = language)
  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (is.null(ctx$local_root)) {
    return(NULL)
  }

  for (rel in study_artifact_rel_candidates(rep)) {
    local <- file.path(ctx$local_root, rel)
    if (file.exists(local)) {
      return(local)
    }
  }
  NULL
}

#' Check whether a precomputed artifact is available
#'
#' @inheritParams render_replication
#' @return Logical scalar.
#'
#' @examples
#' \dontrun{
#' artifact_available("10.1177/00491241211036161", "fig_1")
#' artifact_available("10.1017/S0003055403000534", "tab_1")
#' artifact_available("rep-template", "tab_1")
#' }
#'
#' @keywords internal
artifact_available <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  local_path <- local_artifact_path(doi, what, repo = repo, folder = folder, language = language)
  if (!is.null(local_path)) {
    return(file.exists(local_path))
  }

  path <- get_artifact_path(doi, what, repo = repo, language = language)
  if (is.null(path)) {
    return(FALSE)
  }

  !is.null(suppressWarnings(tryCatch(
    load_artifact(doi, what, repo = repo, folder = folder, language = language),
    error = function(e) NULL
  )))
}

#' Validate that a single precomputed output exists
#'
#' @inheritParams render_replication
#' @return Invisibly \code{TRUE} on success.
#' @keywords internal
validate_single_output <- function(doi, what, repo = NULL, folder = NULL, language = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    if (!artifact_available(doi, what, repo = repo, folder = folder, language = language)) {
      pkg <- as.character(meta$paper$package[[1]])
      stop(
        "Artifact not available for replication ", what,
        ". Run ", study_build_function("package"), "(",
        shQuote(pkg, type = "sh"), ", install_deps = TRUE).",
        call. = FALSE
      )
    }
    return(invisible(TRUE))
  }

  local_path <- local_artifact_path(doi, what, repo = repo, language = language)
  if (!is.null(local_path) && file.exists(local_path)) {
    return(invisible(TRUE))
  }
  if (!is.null(local_path) && !file.exists(local_path)) {
    ctx <- tryCatch(paper_context(doi, repo = repo, folder = folder), error = function(e) NULL)
    hint <- if (!is.null(ctx) && isTRUE(ctx$is_folder_study)) {
      ". Run build_study_outputs() in the study repository."
    } else {
      ". Run scripts/build_artifacts.R in the registry."
    }
    stop(
      "Missing artifact file: ", local_path,
      hint,
      call. = FALSE
    )
  }

  if (!artifact_available(doi, what, repo = repo, language = language)) {
    stop(
      "Artifact not available for replication ", what, ".",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Whether a step is exempt from baked Display-sink requirements
#'
#' Gap steps (\code{incomplete} / \code{data_unavailable} / \code{requires_engine})
#' may omit display sinks; Shiny shows Code + a clean gap message instead.
#' @keywords internal
step_exempt_from_display_sink <- function(entry) {
  if (is.null(entry) || !is.list(entry)) {
    return(FALSE)
  }
  if (isTRUE(entry$incomplete %||% FALSE)) {
    return(TRUE)
  }
  if (nzchar(as.character(step_data_unavailable(entry) %||% ""))) {
    return(TRUE)
  }
  req <- tolower(trimws(as.character(
    entry$requires_engine[[1]] %||% entry$requires_engine %||% ""
  )))
  nzchar(req) && !req %in% c("r", "stata", "python", "dataverse")
}

#' Check that claimed steps have Display sinks Shiny can show without errors
#'
#' Tables/figures need baked html/png. Pattern B Dataverse access steps need
#' resolvable file-id wiring (Display uses a yaml summary; binary may be
#' gitignored). Other transform steps with displayable \code{outputs:}
#' (html/png/rds/svg) must have those files on disk.
#'
#' @param meta Parsed replication.yml.
#' @param study_root Local study or package root.
#' @return Data frame of check rows (same shape as [check_result()] binds).
#' @keywords internal
check_display_sink_rows <- function(meta, study_root) {
  checks <- bind_check_results()
  entries <- tryCatch(collect_replication_entries(meta), error = function(e) list())
  if (!length(entries)) {
    return(checks)
  }
  for (entry in entries) {
    rid <- as.character(entry$id[[1]] %||% entry$id %||% "")
    if (!nzchar(rid) || identical(as.character(entry$type %||% ""), "format")) {
      next
    }
    if (step_exempt_from_display_sink(entry)) {
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("display_sink_", rid),
          TRUE,
          "gap step — Display sink optional"
        )
      )
      next
    }
    rtype <- tolower(as.character(entry$type %||% ""))
    if (rtype %in% c("table", "figure")) {
      # Already covered by artifact_* checks; skip duplicate.
      next
    }
    if (is_dataverse_file_access_prep_step(entry, meta = meta) ||
        is_dataverse_replication(entry, meta$paper %||% NULL)) {
      entries_dv <- tryCatch(
        dataverse_access_step_entries(entry, meta = meta),
        error = function(e) list()
      )
      ok <- length(entries_dv) > 0L &&
        all(vapply(entries_dv, function(e) {
          nzchar(as.character(e$id %||% e$file_id %||% e$url %||% "")) &&
            nzchar(as.character(e$path %||% ""))
        }, logical(1)))
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("display_sink_", rid),
          ok,
          if (ok) {
            "Dataverse access Display summary wired"
          } else {
            paste0(
              "engine: dataverse step '", rid,
              "' needs file_id (or files:/url) + outputs: so Display/Run work without ",
              "'output not on disk' / 'not available for language' errors"
            )
          }
        )
      )
      next
    }
    if (is_dataverse_access_prep_step(entry, meta, ctx = NULL)) {
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("display_sink_", rid),
          TRUE,
          "Dataverse deposit Display summary wired"
        )
      )
      next
    }
    outs <- character(0)
    if (!is.null(entry$outputs) && length(entry$outputs)) {
      outs <- vapply(entry$outputs, function(x) as.character(x[[1]] %||% x), character(1))
      outs <- outs[nzchar(outs)]
    }
    displayable <- outs[grepl("\\.(html|png|rds|svg)$", outs, ignore.case = TRUE)]
    if (!length(displayable)) {
      # Non-display transform (e.g. intermediate .dta only) — OK for Display gap
      # as long as Shiny does not claim a precomputed table/figure.
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("display_sink_", rid),
          TRUE,
          "no html/png/rds/svg display sink declared"
        )
      )
      next
    }
    missing <- character(0)
    for (rel in displayable) {
      path <- file.path(study_root, rel)
      if (!file.exists(path)) {
        missing <- c(missing, rel)
      }
    }
    checks <- bind_check_results(
      checks,
      check_result(
        paste0("display_sink_", rid),
        length(missing) == 0L,
        if (length(missing) == 0L) {
          paste(displayable, collapse = ", ")
        } else {
          paste0(
            "Missing Display sink(s): ", paste(missing, collapse = ", "),
            " (Shiny would show 'not on disk' / 'No precomputed …'; bake or mark incomplete)"
          )
        }
      )
    )
  }
  checks
}

#' Validate all precomputed outputs for one paper
#'
#' @param doi Character. DOI of the paper.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name.
#' @return Invisibly \code{TRUE} if every replication has an artifact.
#' @keywords internal
validate_paper_outputs <- function(doi, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  display_reps <- folder_display_replications(meta)
  missing <- character(0)

  for (rep in display_reps) {
    tryCatch({
      validate_single_output(doi, rep$id, repo = repo, folder = folder)
    }, error = function(e) {
      missing <<- c(missing, paste0(rep$id, ": ", conditionMessage(e)))
    })
  }

  if (length(missing) > 0) {
    stop(
      "Missing artifacts for ", doi, ":\n",
      paste0(" - ", missing, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Validate precomputed outputs for every study in a registry checkout
#'
#' @param registry_root Path to the registry repository.
#' @param folders Optional character vector of study folder names.
#' @return Invisibly \code{TRUE} if every study passes.
#' @keywords internal
validate_registry_outputs <- function(registry_root = NULL, folders = NULL) {
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
    sub("^studies/", "", sub("\\.yml$", "", basename(folders)))
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
      message("Checking ", folder, " (package-backed) ...")
    } else {
      ctx <- paper_context(lookup, folder = folder)
      if (isTRUE(ctx$is_folder_study)) {
        message(
          "Checking ", folder, " (folder-backed; study repo ",
          ctx$materials_repo, ") ..."
        )
      } else {
        message("Checking ", folder, " ...")
      }
    }

    tryCatch(
      validate_paper_outputs(lookup, folder = folder),
      error = function(e) {
        failures <<- c(failures, paste0(folder, ": ", conditionMessage(e)))
      }
    )
  }

  if (length(failures) > 0) {
    stop(
      "Missing registry artifacts:\n",
      paste0(" - ", failures, collapse = "\n"),
      "\nFor folder-backed studies, run build_study_outputs() in each study repo.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Validate precomputed outputs
#'
#' Maintainer helper: checks that declared table and figure outputs exist on
#' disk (folder-backed studies: study repo \code{outputs/}; package-backed:
#' installed package report outputs). Does not run live replications.
#'
#' @param doi Character DOI, or \code{"everywhere"} to check every registry
#'   study. Ignored when \code{location} is set.
#' @param what Replication id, or \code{"everything"} (default when \code{doi}
#'   or \code{location} is set) to check every table and figure in scope.
#' @param location Local study path or GitHub address. When set, validates
#'   outputs for that study repository (equivalent to passing its DOI with
#'   \code{what = "everything"}).
#' @param registry_root Optional registry checkout for monorepo dev. Used with
#'   \code{doi = "everywhere"} or \code{location}.
#' @param folders Optional character vector of registry folder names when
#'   \code{doi = "everywhere"}. Defaults to all \code{studies/*.yml} stubs.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name (for a single \code{doi}).
#' @param language Optional engine language for multi-engine replications.
#' @return Invisibly \code{TRUE} on success.
#' @seealso [check_replication()], [build_outputs()], [build_study_outputs()]
#' @export
#'
#' @examples
#' \dontrun{
#' validate_outputs(doi = "10.1177/00491241211036161", what = "fig_1")
#' validate_outputs(doi = "10.1017/S0003055403000534", what = "tab_1")
#' validate_outputs(doi = "10.1017/S0003055422000284", what = "everything")
#' validate_outputs(doi = "rep-template", what = "tab_1")
#' validate_outputs(location = ".")
#' options(replicateEverything.registry_root = "../registry")
#' validate_outputs(doi = "everywhere", what = "everything")
#' validate_outputs(doi = "everywhere", folders = "10.1017_s0003055403000534")
#' }
validate_outputs <- function(
  doi = NULL,
  what = NULL,
  location = NULL,
  registry_root = NULL,
  folders = NULL,
  repo = NULL,
  folder = NULL,
  language = NULL
) {
  if (identical(doi, "everywhere")) {
    if (!is.null(what) && !identical(what, "everything")) {
      stop(
        'When doi = "everywhere", what must be "everything" or NULL.',
        call. = FALSE
      )
    }
    return(validate_registry_outputs(registry_root = registry_root, folders = folders))
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
      return(validate_paper_outputs(study_doi, repo = repo, folder = study_folder))
    }
    return(validate_single_output(
      study_doi,
      what,
      repo = repo,
      folder = study_folder,
      language = language
    ))
  }

  if (is.null(doi)) {
    stop(
      'Provide doi, location, or doi = "everywhere".',
      call. = FALSE
    )
  }

  if (is.null(what) || identical(what, "everything")) {
    return(validate_paper_outputs(doi, repo = repo, folder = folder))
  }

  validate_single_output(doi, what, repo = repo, folder = folder, language = language)
}

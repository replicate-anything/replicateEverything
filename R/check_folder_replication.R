#' Validate a folder-backed replication study
#'
#' Runs a transparent checklist: study layout, `replication.yml`, code and data
#' paths, baked artifacts under `artifacts/`, optional `tests/testthat/`, and
#' (optionally) live execution of every table and figure.
#'
#' @param location Local study path or GitHub address (`org/repo` or URL).
#'   Defaults to the current working directory when it contains
#'   `replication.yml`.
#' @param full_replication If `TRUE`, also run every table and figure via
#'   [run_replication()] and require success.
#' @param registry_root Optional path to the registry checkout (sibling of the
#'   study repo in a monorepo). Defaults to
#'   `getOption("replicateEverything.registry_root")`.
#' @return A list with `ok` (logical), `checks` (data frame), and `study_path`.
#' @export
check_folder_replication <- function(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL
) {
  checks <- bind_check_results()
  study_root <- tryCatch(
    resolve_study_location(location),
    error = function(e) {
      checks <<- bind_check_results(
        checks,
        check_result("resolve_location", FALSE, conditionMessage(e))
      )
      NULL
    }
  )

  if (is.null(study_root)) {
    return(structure(
      list(ok = FALSE, checks = checks, study_path = NA_character_),
      class = c("folder_replication_check", "replication_check", "list")
    ))
  }
  checks <- bind_check_results(
    checks,
    check_result("resolve_location", TRUE, study_root)
  )

  meta <- read_study_replication_yaml(study_root)
  if (is.null(meta)) {
    checks <- bind_check_results(
      checks,
      check_result("replication_yml", FALSE, "Missing replication.yml at study root")
    )
    return(structure(
      list(ok = FALSE, checks = checks, study_path = study_root),
      class = c("folder_replication_check", "replication_check", "list")
    ))
  }
  checks <- bind_check_results(
    checks,
    check_result("replication_yml", TRUE, "Found replication.yml")
  )

  paper <- meta$paper %||% list()
  if (is.null(paper$doi) || !nzchar(as.character(paper$doi[[1]]))) {
    checks <- bind_check_results(
      checks,
      check_result("paper_doi", FALSE, "paper.doi is required")
    )
  } else {
    checks <- bind_check_results(
      checks,
      check_result("paper_doi", TRUE, normalize_doi(paper$doi))
    )
  }

  if (is.null(paper$title) || !nzchar(as.character(paper$title[[1]]))) {
    checks <- bind_check_results(
      checks,
      check_result("paper_title", FALSE, "paper.title is required")
    )
  } else {
    checks <- bind_check_results(
      checks,
      check_result("paper_title", TRUE, as.character(paper$title[[1]]))
    )
  }

  study_repo <- infer_study_repo_slug(study_root, meta)
  if (is.null(study_repo) || !nzchar(as.character(study_repo[[1]]))) {
    checks <- bind_check_results(
      checks,
      check_result("study_repo", FALSE, "Set repo or paper.study_repo to the GitHub slug")
    )
  } else {
    checks <- bind_check_results(
      checks,
      check_result("study_repo", TRUE, as.character(study_repo[[1]]))
    )
  }

  display_reps <- folder_display_replications(meta)
  if (length(display_reps) == 0) {
    checks <- bind_check_results(
      checks,
      check_result("replications_list", FALSE, "No figure/table entries in replications:")
    )
  } else {
    checks <- bind_check_results(
      checks,
      check_result("replications_list", TRUE, paste(length(display_reps), "entries"))
    )
  }

  for (rep in display_reps) {
    rid <- rep$id
    missing <- character(0)
    for (field in c("id", "type", "code")) {
      val <- rep[[field]] %||% NULL
      if (is.null(val) || !nzchar(as.character(val[[1]]))) {
        missing <- c(missing, field)
      }
    }
    if (length(missing)) {
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("replication_", rid, "_meta"),
          FALSE,
          paste("Missing fields:", paste(missing, collapse = ", "))
        )
      )
      next
    }
    checks <- bind_check_results(
      checks,
      check_result(paste0("replication_", rid, "_meta"), TRUE, rep$code)
    )

    code_path <- file.path(study_root, as.character(rep$code[[1]]))
    checks <- bind_check_results(
      checks,
      check_result(
        paste0("code_", rid),
        file.exists(code_path),
        if (file.exists(code_path)) code_path else paste("Missing", rep$code)
      )
    )

    data_paths <- replication_data_paths(rep)
    for (rel in data_paths) {
      data_path <- file.path(study_root, rel)
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("data_", rid, "_", gsub("[^a-zA-Z0-9._-]", "_", rel)),
          file.exists(data_path),
          if (file.exists(data_path)) data_path else paste("Missing", rel)
        )
      )
    }
  }

  artifact_dir <- file.path(study_root, "artifacts")
  if (!dir.exists(artifact_dir)) {
    checks <- bind_check_results(
      checks,
      check_result(
        "artifact_directory",
        FALSE,
        "Missing artifacts/ (run build_study_artifacts())"
      )
    )
  } else {
    checks <- bind_check_results(
      checks,
      check_result("artifact_directory", TRUE, artifact_dir)
    )
  }

  for (rep in display_reps) {
    rid <- as.character(rep$id[[1]])
    rtype <- as.character(rep$type[[1]])
    rel <- study_artifact_rel_path(rep)
    art_path <- file.path(study_root, rel)
    if (!file.exists(art_path)) {
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("artifact_", rid),
          FALSE,
          paste0("Missing ", rel, " (run build_study_artifacts())")
        )
      )
      next
    }
    if (identical(rtype, "figure")) {
      ok_png <- grepl("\\.png$", art_path, ignore.case = TRUE) && file.size(art_path) > 100
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("artifact_", rid),
          ok_png,
          if (ok_png) art_path else "Figure artifact must be a non-empty PNG"
        )
      )
    } else {
      ext <- tolower(tools::file_ext(art_path))
      ok_table <- if (identical(ext, "html")) {
        html <- paste(readLines(art_path, warn = FALSE), collapse = "\n")
        grepl("<table", html, ignore.case = TRUE)
      } else if (identical(ext, "rds")) {
        TRUE
      } else {
        FALSE
      }
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("artifact_", rid),
          ok_table,
          if (ok_table) art_path else "Table artifact must be HTML with <table> or .rds"
        )
      )
    }
  }

  manifest_path <- file.path(artifact_dir, "manifest.json")
  checks <- bind_check_results(
    checks,
    check_result(
      "manifest_json",
      file.exists(manifest_path),
      if (file.exists(manifest_path)) manifest_path else "Missing artifacts/manifest.json"
    )
  )

  test_dir <- file.path(study_root, "tests", "testthat")
  checks <- bind_check_results(
    checks,
    check_result(
      "testthat_directory",
      dir.exists(test_dir),
      if (dir.exists(test_dir)) test_dir else "Recommended: tests/testthat/ with run_replication checks"
    )
  )

  if (isTRUE(full_replication)) {
    if (is.null(registry_root) || !nzchar(registry_root)) {
      registry_root <- getOption("replicateEverything.registry_root", NULL)
    }
    run_opts <- folder_study_run_options(study_root, meta, registry_root = registry_root)
    doi <- normalize_doi(paper$doi)

    old_opts <- options(run_opts)
    on.exit(options(old_opts), add = TRUE)

    for (rep in display_reps) {
      rid <- as.character(rep$id[[1]])
      live_ok <- tryCatch(
        {
          use_format <- format_specified(rep)
          obj <- run_replication(
            doi,
            rid,
            install_deps = TRUE,
            format = use_format
          )
          if (identical(rep$type, "figure")) {
            inherits(obj, "ggplot") || inherits(obj, "gg") || inherits(obj, "gtable")
          } else if (use_format) {
            is.character(obj) || inherits(obj, "knitr_kable") ||
              grepl("<table", as.character(obj)[1], ignore.case = TRUE)
          } else {
            !is.null(obj)
          }
        },
        error = function(e) e
      )
      if (inherits(live_ok, "error")) {
        checks <- bind_check_results(
          checks,
          check_result(
            paste0("live_", rid),
            FALSE,
            conditionMessage(live_ok)
          )
        )
      } else {
        checks <- bind_check_results(
          checks,
          check_result(
            paste0("live_", rid),
            isTRUE(live_ok),
            if (isTRUE(live_ok)) "run_replication() OK" else "Unexpected output type"
          )
        )
      }
    }
  }

  list(
    ok = all(checks$passed),
    checks = checks,
    study_path = study_root,
    meta = meta
  ) |> structure(class = c("folder_replication_check", "replication_check", "list"))
}

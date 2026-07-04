#' Validate a package-backed replication study
#'
#' Runs a transparent checklist: package layout, `replication.yml`, exported API,
#' baked artifacts, and (optionally) live execution of every table and figure.
#'
#' @param location Local package path or GitHub address (`org/repo` or URL).
#' @param full_replication If `TRUE`, also run every table and figure via
#'   `run_replication()` and require success.
#' @return A list with `ok` (logical), `checks` (data frame), and `package_path`.
#'
#' @examples
#' \dontrun{
#' check_package_replication("../rep-10.1371_journal.pone.0278337")
#' check_package_replication("../rep-10.1371_journal.pone.0278337", full_replication = TRUE)
#' }
#'
#' @export
check_package_replication <- function(location, full_replication = FALSE) {
  checks <- bind_check_results()
  pkg_root <- tryCatch(
    resolve_package_location(location),
    error = function(e) {
      checks <<- bind_check_results(
        checks,
        check_result("resolve_location", FALSE, conditionMessage(e))
      )
      NULL
    }
  )

  if (is.null(pkg_root)) {
    return(structure(
      list(ok = FALSE, checks = checks, package_path = NA_character_),
      class = c("package_replication_check", "list")
    ))
  }
  checks <- bind_check_results(
    checks,
    check_result("resolve_location", TRUE, pkg_root)
  )

  desc_path <- file.path(pkg_root, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    checks <- bind_check_results(
      checks,
      check_result("description_file", FALSE, "Missing DESCRIPTION")
    )
    return(structure(
      list(ok = FALSE, checks = checks, package_path = pkg_root),
      class = c("package_replication_check", "list")
    ))
  }
  desc <- read.dcf(desc_path)
  pkg_name <- as.character(desc[1, "Package"])
  checks <- bind_check_results(
    checks,
    check_result("description_file", TRUE, pkg_name)
  )

  meta <- read_package_replication_yaml(pkg_root)
  if (is.null(meta)) {
    checks <- bind_check_results(
      checks,
      check_result("replication_yml", FALSE, "Missing replication.yml (root or inst/)")
    )
    return(structure(
      list(ok = FALSE, checks = checks, package_path = pkg_root),
      class = c("package_replication_check", "list")
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

  yml_pkg <- paper$package %||% NULL
  if (is.null(yml_pkg) || !nzchar(as.character(yml_pkg[[1]]))) {
    checks <- bind_check_results(
      checks,
      check_result("paper_package", FALSE, "paper.package is required")
    )
  } else if (!identical(as.character(yml_pkg[[1]]), pkg_name)) {
    checks <- bind_check_results(
      checks,
      check_result(
        "paper_package",
        FALSE,
        paste0("paper.package (", yml_pkg, ") must match DESCRIPTION Package (", pkg_name, ")")
      )
    )
  } else {
    checks <- bind_check_results(
      checks,
      check_result("paper_package", TRUE, pkg_name)
    )
  }

  pkg_repo <- meta$repo %||% paper$package_repo %||% NULL
  if (is.null(pkg_repo) || !nzchar(as.character(pkg_repo[[1]]))) {
    checks <- bind_check_results(
      checks,
      check_result("package_repo", FALSE, "Set repo or paper.package_repo to the GitHub slug")
    )
  } else {
    checks <- bind_check_results(
      checks,
      check_result("package_repo", TRUE, as.character(pkg_repo[[1]]))
    )
  }

  reps <- meta$replications %||% list()
  display_reps <- reps[vapply(reps, function(x) {
    identical(as.character(x$type %||% ""), "figure") ||
      identical(as.character(x$type %||% ""), "table")
  }, logical(1))]
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
    for (field in c("id", "type", "make", "format")) {
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
      check_result(paste0("replication_", rid, "_meta"), TRUE, rep$make)
    )
  }

  load_ok <- tryCatch(
    load_replication_package_path(pkg_root, pkg_name),
    error = function(e) e
  )
  if (inherits(load_ok, "error")) {
    checks <- bind_check_results(
      checks,
      check_result("load_package", FALSE, conditionMessage(load_ok))
    )
    return(structure(
      list(ok = all(checks$passed), checks = checks, package_path = pkg_root),
      class = c("package_replication_check", "list")
    ))
  }
  checks <- bind_check_results(
    checks,
    check_result("load_package", TRUE, "Package loaded")
  )

  if (!requireNamespace(pkg_name, quietly = TRUE)) {
    checks <- bind_check_results(
      checks,
      check_result("namespace", FALSE, "Package not available after load")
    )
    return(structure(
      list(ok = FALSE, checks = checks, package_path = pkg_root),
      class = c("package_replication_check", "list")
    ))
  }
  ns <- asNamespace(pkg_name)

  for (fn in PACKAGE_REPLICATION_API) {
    exists_fn <- exists(fn, envir = ns, inherits = FALSE)
    checks <- bind_check_results(
      checks,
      check_result(
        paste0("api_", fn),
        exists_fn,
        if (exists_fn) "exported" else "missing exported function"
      )
    )
  }

  for (rep in display_reps) {
    rid <- rep$id
    for (fn_name in c(rep$make, rep$format)) {
      fn_name <- as.character(fn_name[[1]])
      has_fn <- exists(fn_name, envir = ns, inherits = FALSE, mode = "function")
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("fn_", fn_name),
          has_fn,
          if (has_fn) "found" else "function not found in package namespace"
        )
      )
    }
  }

  artifact_dir <- file.path(pkg_root, "inst", "report", "artifacts")
  if (!dir.exists(artifact_dir)) {
    checks <- bind_check_results(
      checks,
      check_result(
        "artifact_directory",
        FALSE,
        "Missing inst/report/artifacts/ (run build_report())"
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
    ext <- if (identical(rtype, "figure")) "png" else "html"
    art_path <- tryCatch(
      call_replication_package(pkg_name, "artifact_file", rid),
      error = function(e) NULL
    )
    if (is.null(art_path) || !nzchar(art_path) || !file.exists(art_path)) {
      fallback <- file.path(artifact_dir, paste0(rid, ".", ext))
      art_path <- if (file.exists(fallback)) fallback else NULL
    }
    if (is.null(art_path)) {
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("artifact_", rid),
          FALSE,
          paste0("Missing inst/report/artifacts/", rid, ".", ext)
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
      html <- tryCatch(
        call_replication_package(pkg_name, "load_artifact", rid),
        error = function(e) NULL
      )
      ok_html <- is.character(html) &&
        length(html) == 1L &&
        nzchar(html) &&
        grepl("<table", html, ignore.case = TRUE)
      checks <- bind_check_results(
        checks,
        check_result(
          paste0("artifact_", rid),
          ok_html,
          if (ok_html) "HTML table artifact" else "Table artifact must be HTML containing a <table>"
        )
      )
    }
  }

  if (isTRUE(full_replication)) {
    for (rep in display_reps) {
      rid <- as.character(rep$id[[1]])
      live_ok <- tryCatch(
        {
          obj <- call_replication_package(pkg_name, "run_replication", rid)
          if (identical(rep$type, "figure")) {
            inherits(obj, "ggplot") || inherits(obj, "gg") || inherits(obj, "gtable")
          } else {
            is.character(obj) || inherits(obj, "knitr_kable") ||
              grepl("<table", as.character(obj)[1], ignore.case = TRUE)
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
    package_path = pkg_root,
    package = pkg_name,
    meta = meta
  ) |> structure(class = c("package_replication_check", "replication_check", "list"))
}

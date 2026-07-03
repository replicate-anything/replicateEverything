#' Infer replication engine from a registry entry
#' @keywords internal
audit_replication_engine <- function(rep) {
  eng <- tolower(as.character(rep$engine %||% ""))
  if (identical(eng, "stata")) {
    return("stata")
  }
  if (identical(eng, "r")) {
    return("r")
  }
  id <- as.character(rep$id %||% "")
  if (grepl("_stata$", id, ignore.case = TRUE)) {
    return("stata")
  }
  code <- as.character(rep$code %||% "")
  if (length(code) == 1L && grepl("\\.do$", code, ignore.case = TRUE)) {
    return("stata")
  }
  "r"
}

#' Display label for a replication entry
#' @keywords internal
audit_replication_label <- function(rep) {
  label <- rep$label %||% rep$description %||% rep$id
  as.character(label[[1]] %||% label)
}

#' Group id for paired R / Stata replications
#' @keywords internal
audit_replication_group <- function(rep) {
  grp <- as.character(rep$group %||% "")
  if (nzchar(grp)) {
    return(grp)
  }
  as.character(rep$id %||% "")
}

#' List audit jobs (one row per engine) from replication entries
#'
#' @param reps List of replication entries from \code{list_replications()}.
#' @return Data frame with columns \code{group}, \code{what}, \code{engine},
#'   \code{label}, and \code{type}.
#' @keywords internal
audit_jobs_from_replications <- function(reps) {
  if (is.null(reps) || !length(reps)) {
    return(NULL)
  }

  reps <- reps[vapply(reps, function(x) {
    is.list(x) && !is.null(x$id) && nzchar(as.character(x$id[[1]] %||% x$id))
  }, logical(1))]
  reps <- reps[vapply(reps, function(x) {
    type <- as.character(x$type %||% "")
    type %in% c("figure", "table")
  }, logical(1))]
  if (!length(reps)) {
    return(NULL)
  }

  groups <- unique(vapply(reps, audit_replication_group, character(1)))
  rows <- lapply(groups, function(group) {
    group_reps <- reps[vapply(reps, function(x) {
      identical(audit_replication_group(x), group)
    }, logical(1))]
    jobs <- list()
    for (eng in c("r", "stata")) {
      eng_reps <- group_reps[vapply(group_reps, function(x) {
        identical(audit_replication_engine(x), eng)
      }, logical(1))]
      if (!length(eng_reps)) {
        next
      }
      rep <- eng_reps[[1]]
      jobs[[length(jobs) + 1L]] <- data.frame(
        group = group,
        what = as.character(rep$id),
        engine = eng,
        label = audit_replication_label(rep),
        type = as.character(rep$type %||% ""),
        stringsAsFactors = FALSE
      )
    }
    if (!length(jobs)) {
      return(NULL)
    }
    do.call(rbind, jobs)
  })

  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(NULL)
  }
  do.call(rbind, rows)
}

#' Truncate an error message for audit output
#' @keywords internal
audit_error_snippet <- function(x, max_chars = 240L) {
  msg <- replication_error_message(x)
  msg <- gsub("\r\n", "\n", msg, fixed = TRUE)
  msg <- trimws(msg)
  msg <- gsub("[ \t]+", " ", msg)
  msg <- gsub("\n+", " | ", msg)
  if (nchar(msg) <= max_chars) {
    return(msg)
  }
  paste0(substr(msg, 1, max_chars), "...")
}

#' Run one replication with a per-object time limit
#'
#' @inheritParams render_replication
#' @param patience Seconds before halting the run (default 20).
#' @return List with \code{success}, \code{seconds}, \code{timed_out}, and
#'   \code{error}.
#' @keywords internal
audit_run_one <- function(
  doi,
  what,
  patience = 20,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL
) {
  patience <- as.numeric(patience)
  if (!is.finite(patience) || patience <= 0) {
    stop("patience must be a positive number of seconds.", call. = FALSE)
  }

  t0 <- proc.time()
  run <- tryCatch(
    {
      setTimeLimit(elapsed = patience, transient = TRUE)
      on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
      result <- render_replication(
        doi,
        what,
        install_deps = install_deps,
        repo = repo,
        folder = folder
      )
      obj <- replication_object(result)
      if (is.null(obj)) {
        stop("Replication returned no object.", call. = FALSE)
      }
      list(ok = TRUE, error = NULL)
    },
    error = function(e) {
      list(ok = FALSE, error = e)
    }
  )
  seconds <- (proc.time() - t0)[["elapsed"]]
  timed_out <- !isTRUE(run$ok) &&
    !is.null(run$error) &&
    grepl("elapsed time limit|cpu time limit", conditionMessage(run$error), ignore.case = TRUE)

  list(
    success = isTRUE(run$ok),
    seconds = seconds,
    timed_out = timed_out,
    error = run$error
  )
}

#' Audit all registry replications
#'
#' Walks the replication registry and attempts every table and figure in each
#' available engine (R and Stata where defined). Failures do not stop the audit;
#' results are returned in a concise data frame and optional Quarto report.
#'
#' @param patience Seconds to allow each table or figure before halting that run.
#'   Defaults to \code{20}.
#' @param index Registry index data frame; defaults to [load_index()].
#' @param dois Optional character vector of DOIs to audit. When \code{NULL},
#'   audits every row in \code{index}.
#' @param install_deps Logical. Passed to [render_replication()].
#' @param verbose Logical. Print progress messages.
#' @return An object of class \code{audit_everything} with components
#'   \code{results} (data frame), \code{summary}, and metadata.
#' @export
#'
#' @examples
#' \dontrun{
#' audit <- audit_everything(patience = 20, dois = "10.1177/00491241211036161")
#' print(audit)
#' }
audit_everything <- function(
  patience = 20,
  index = NULL,
  dois = NULL,
  install_deps = FALSE,
  verbose = TRUE
) {
  patience <- as.numeric(patience)
  if (!is.finite(patience) || patience <= 0) {
    stop("patience must be a positive number of seconds.", call. = FALSE)
  }

  if (is.null(index)) {
    index <- load_index()
  }
  if (is.null(index) || nrow(index) == 0) {
    stop("Registry index is empty.", call. = FALSE)
  }

  if (!is.null(dois)) {
    dois_norm <- vapply(dois, normalize_doi, character(1))
    index_dois <- vapply(index$doi, normalize_doi, character(1))
    index <- index[index_dois %in% dois_norm, , drop = FALSE]
    if (nrow(index) == 0) {
      stop("No matching studies in registry index.", call. = FALSE)
    }
  }

  started_at <- Sys.time()
  results <- list()

  for (i in seq_len(nrow(index))) {
    row <- index[i, , drop = FALSE]
    doi <- normalize_doi(row$doi[[1]])
    title <- as.character(row$title[[1]] %||% doi)
    folder <- if ("folder" %in% names(row)) row$folder[[1]] else NULL
    repo <- if ("repo" %in% names(row)) row$repo[[1]] else NULL

    if (isTRUE(verbose)) {
      message(sprintf("[%d/%d] %s", i, nrow(index), title))
    }

    reps <- tryCatch(
      list_replications(doi, repo = repo, folder = folder),
      error = function(e) e
    )

    if (inherits(reps, "error")) {
      results[[length(results) + 1L]] <- data.frame(
        doi = doi,
        title = title,
        object = NA_character_,
        object_label = NA_character_,
        type = NA_character_,
        engine = NA_character_,
        success = FALSE,
        seconds = NA_real_,
        timed_out = FALSE,
        error_snippet = audit_error_snippet(reps),
        stringsAsFactors = FALSE
      )
      next
    }

    jobs <- audit_jobs_from_replications(reps)
    if (is.null(jobs) || nrow(jobs) == 0) {
      results[[length(results) + 1L]] <- data.frame(
        doi = doi,
        title = title,
        object = NA_character_,
        object_label = "(no tables or figures)",
        type = NA_character_,
        engine = NA_character_,
        success = FALSE,
        seconds = NA_real_,
        timed_out = FALSE,
        error_snippet = "No table or figure replications listed for this study.",
        stringsAsFactors = FALSE
      )
      next
    }

    for (j in seq_len(nrow(jobs))) {
      job <- jobs[j, , drop = FALSE]
      what <- job$what[[1]]
      engine <- job$engine[[1]]
      label <- job$label[[1]]
      type <- job$type[[1]]

      if (isTRUE(verbose)) {
        message(sprintf("  - %s (%s, %s)", label, what, engine))
      }

      run <- audit_run_one(
        doi,
        what,
        patience = patience,
        install_deps = install_deps,
        repo = repo,
        folder = folder
      )

      results[[length(results) + 1L]] <- data.frame(
        doi = doi,
        title = title,
        object = what,
        object_label = label,
        type = type,
        engine = engine,
        success = run$success,
        seconds = run$seconds,
        timed_out = run$timed_out,
        error_snippet = if (run$success) "" else audit_error_snippet(run$error),
        stringsAsFactors = FALSE
      )
    }
  }

  results_df <- do.call(rbind, results)
  rownames(results_df) <- NULL

  finished_at <- Sys.time()
  n_ok <- sum(results_df$success, na.rm = TRUE)
  n_fail <- sum(!results_df$success, na.rm = TRUE)
  n_timeout <- sum(results_df$timed_out, na.rm = TRUE)

  structure(
    list(
      patience = patience,
      started_at = started_at,
      finished_at = finished_at,
      results = results_df,
      summary = list(
        studies = nrow(index),
        runs = nrow(results_df),
        success = n_ok,
        failed = n_fail,
        timed_out = n_timeout
      )
    ),
    class = "audit_everything"
  )
}

#' @export
print.audit_everything <- function(x, ...) {
  sm <- x$summary
  cat(
    "replicateEverything registry audit\n",
    sprintf(
      "Patience: %gs | Studies: %d | Runs: %d | OK: %d | Failed: %d | Timed out: %d\n",
      x$patience,
      sm$studies,
      sm$runs,
      sm$success,
      sm$failed,
      sm$timed_out
    ),
    sep = ""
  )
  if (sm$failed > 0L) {
    cat("\nFailures by study:\n")
    fails <- x$results[!x$results$success, , drop = FALSE]
    studies <- unique(fails$title)
    for (study in studies) {
      sf <- fails[fails$title == study, , drop = FALSE]
      cat(sprintf("  %s\n", study))
      for (k in seq_len(nrow(sf))) {
        row <- sf[k, , drop = FALSE]
        obj <- row$object[[1]]
        if (is.na(obj) || !nzchar(obj)) {
          cat(sprintf("    - %s\n", row$error_snippet[[1]]))
        } else {
          tag <- if (isTRUE(row$timed_out[[1]])) " [timed out]" else ""
          cat(sprintf(
            "    - %s (%s, %s)%s: %s\n",
            row$object_label[[1]],
            obj,
            row$engine[[1]],
            tag,
            row$error_snippet[[1]]
          ))
        }
      }
    }
  }
  invisible(x)
}

#' Path to the bundled audit Quarto document
#'
#' @return Character path, or \code{""} if not found.
#' @export
audit_everything_qmd <- function() {
  installed <- system.file("audit", "audit_everything.qmd", package = "replicateEverything")
  if (nzchar(installed)) {
    return(installed)
  }
  pkg_root <- find.package("replicateEverything")
  dev_path <- file.path(dirname(pkg_root), "audit_everything.qmd")
  if (file.exists(dev_path)) {
    return(normalizePath(dev_path, winslash = "/", mustWork = FALSE))
  }
  ""
}

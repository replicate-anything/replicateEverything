#' Compare replicated GLM tables to published benchmarks
#'
#' Checks coefficient estimates, standard errors, and sample sizes for a
#' vector of models against values taken from the published table. Intended
#' for study repos under \code{tests/substantive/<step_id>.R}.
#'
#' @param models A list of fitted \code{glm} objects (one per table column).
#' @param spec Benchmark specification with character vector \code{terms} and
#'   numeric vectors \code{coef}, \code{se}, and \code{nobs} (same length).
#' @param tolerance Maximum absolute difference allowed for coefficients and
#'   standard errors (default \code{0.001}, matching three decimal places).
#' @return Invisibly \code{TRUE} on success.
#' @export
#'
#' @examples
#' \dontrun{
#' models <- run_replication("10.1017/S0003055403000534", "tab_1")
#' check_glm_table_benchmark(models, list(
#'   terms = c("warl", "warl", "warl", "empwarl", "cowwarl"),
#'   coef = c(-0.954, -0.849, -0.916, -0.688, -0.551),
#'   se = c(0.314, 0.388, 0.312, 0.264, 0.374),
#'   nobs = c(6327, 5186, 6327, 6360, 5378)
#' ))
#' }
check_glm_table_benchmark <- function(models, spec, tolerance = 0.001) {
  if (!is.list(models) || length(models) == 0L) {
    stop("models must be a non-empty list of glm objects.", call. = FALSE)
  }
  required <- c("terms", "coef", "se", "nobs")
  missing <- setdiff(required, names(spec))
  if (length(missing) > 0L) {
    stop(
      "spec must include: ",
      paste(required, collapse = ", "),
      call. = FALSE
    )
  }
  n <- length(spec$coef)
  if (!all(vapply(spec[c("terms", "se", "nobs")], length, integer(1)) == n)) {
    stop("spec$terms, spec$coef, spec$se, and spec$nobs must have equal length.", call. = FALSE)
  }
  if (length(models) != n) {
    stop(
      "Expected ", n, " models but got ", length(models), ".",
      call. = FALSE
    )
  }

  tolerance <- as.numeric(tolerance)
  failures <- character(0)

  for (i in seq_len(n)) {
    model <- models[[i]]
    term <- as.character(spec$terms[[i]])
    col <- paste0("model ", i)

    if (!inherits(model, "glm")) {
      failures <- c(failures, paste0(col, ": not a glm object"))
      next
    }
    if (!term %in% names(coef(model))) {
      failures <- c(
        failures,
        paste0(col, ": term ", shQuote(term), " not in model coefficients")
      )
      next
    }

    actual_coef <- unname(coef(model)[term])
    actual_se <- sqrt(unname(vcov(model)[term, term]))
    actual_n <- stats::nobs(model)

    if (abs(actual_coef - spec$coef[[i]]) > tolerance) {
      failures <- c(
        failures,
        sprintf(
          "%s %s coef: expected %.3f, got %.3f",
          col, term, spec$coef[[i]], actual_coef
        )
      )
    }
    if (abs(actual_se - spec$se[[i]]) > tolerance) {
      failures <- c(
        failures,
        sprintf(
          "%s %s se: expected %.3f, got %.3f",
          col, term, spec$se[[i]], actual_se
        )
      )
    }
    if (actual_n != spec$nobs[[i]]) {
      failures <- c(
        failures,
        sprintf(
          "%s N: expected %d, got %d",
          col, spec$nobs[[i]], actual_n
        )
      )
    }
  }

  if (length(failures) > 0L) {
    stop(
      "Published benchmark check failed:\n",
      paste0(" - ", failures, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Path to a study substantive-check script
#' @keywords internal
substantive_check_path <- function(study_root, what) {
  if (is.null(study_root) || !nzchar(study_root)) {
    return("")
  }
  path <- file.path(study_root, "tests", "substantive", paste0(what, ".R"))
  if (file.exists(path)) {
    return(normalizePath(path, winslash = "/", mustWork = FALSE))
  }
  ""
}

#' Load a study substantive-check function, if defined
#'
#' Looks for \code{tests/substantive/<what>.R} defining
#' \code{substantive_check_<what>()} or \code{substantive_check()}.
#'
#' @keywords internal
load_substantive_check_fn <- function(study_root, what) {
  path <- substantive_check_path(study_root, what)
  if (!nzchar(path)) {
    return(NULL)
  }

  env <- new.env(parent = globalenv())
  tryCatch(
    sys.source(path, envir = env, keep.source = FALSE),
    error = function(e) {
      stop(
        "Could not source substantive check ",
        path,
        ": ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )

  fn_name <- paste0("substantive_check_", gsub("[^a-zA-Z0-9_]", "_", what))
  if (exists(fn_name, envir = env, inherits = FALSE)) {
    return(get(fn_name, envir = env, inherits = FALSE))
  }
  if (exists("substantive_check", envir = env, inherits = FALSE)) {
    return(get("substantive_check", envir = env, inherits = FALSE))
  }

  stop(
    "Substantive check script ",
    path,
    " must define ",
    fn_name,
    "() or substantive_check().",
    call. = FALSE
  )
}

#' Whether a study defines a substantive check for a replication step
#' @keywords internal
has_substantive_check <- function(study_root, what) {
  nzchar(substantive_check_path(study_root, what))
}

#' Resolve local study root for substantive checks
#' @keywords internal
substantive_check_study_root <- function(doi, repo = NULL, folder = NULL) {
  ctx <- tryCatch(
    paper_context(doi, repo = repo, folder = folder),
    error = function(e) NULL
  )
  if (!is.null(ctx$local_root) && dir.exists(ctx$local_root)) {
    return(normalizePath(ctx$local_root, winslash = "/", mustWork = FALSE))
  }
  if (!is.null(repo) && nzchar(as.character(repo))) {
    root <- resolve_study_repo_local_root(as.character(repo))
    if (!is.null(root) && dir.exists(root)) {
      return(normalizePath(root, winslash = "/", mustWork = FALSE))
    }
  }
  NULL
}

#' Run a study substantive check on a replication result
#'
#' @param object Analysis object returned by [render_replication()].
#' @param doi Study DOI or registry handle.
#' @param what Replication step id.
#' @param study_root Optional study repository root. Resolved from \code{doi}
#'   when omitted.
#' @param repo Optional registry repo slug.
#' @param folder Optional registry folder name.
#' @return List with \code{checked} (logical), \code{ok} (logical or \code{NA}),
#'   and \code{message} (character).
#' @keywords internal
run_substantive_check <- function(
  object,
  doi,
  what,
  study_root = NULL,
  repo = NULL,
  folder = NULL
) {
  study_root <- study_root %||% substantive_check_study_root(doi, repo = repo, folder = folder)
  if (is.null(study_root) || !has_substantive_check(study_root, what)) {
    return(list(checked = FALSE, ok = NA, message = ""))
  }

  fn <- load_substantive_check_fn(study_root, what)
  out <- tryCatch(
    {
      fn(object)
      list(checked = TRUE, ok = TRUE, message = "")
    },
    error = function(e) {
      list(
        checked = TRUE,
        ok = FALSE,
        message = conditionMessage(e)
      )
    }
  )
  out
}

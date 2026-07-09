#' Ensure replication package dependencies are available
#'
#' @param replication_meta A single replication entry from \code{replication.yml}.
#' @param paper_meta Optional paper-level metadata list.
#' @param install_missing Logical. Install missing CRAN packages when \code{TRUE}.
#'
#' @importFrom stats na.omit
#'
#' @return Invisibly \code{TRUE}.
#' @keywords internal
ensure_replication_dependencies <- function(
  replication_meta,
  paper_meta = NULL,
  install_missing = FALSE
) {
  deps <- character(0)

  if (!is.null(paper_meta) && !is.null(paper_meta$dependencies)) {
    deps <- c(deps, unlist(paper_meta$dependencies, use.names = FALSE))
  }

  if (!is.null(replication_meta) && !is.null(replication_meta$dependencies)) {
    # Entry-level dependencies are engine-specific (Stata SSC, pip, etc.).
    if (identical(replication_engine(replication_meta, paper_meta), "r")) {
      deps <- c(deps, unlist(replication_meta$dependencies, use.names = FALSE))
    }
  }

  deps <- unique(na.omit(as.character(deps)))
  deps <- deps[nzchar(deps)]

  if (length(deps) == 0) {
    return(invisible(TRUE))
  }

  missing <- deps[!vapply(deps, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing) == 0) {
    return(invisible(TRUE))
  }

  if (!install_missing) {
    stop(
      "Missing required replication dependencies: ",
      paste(missing, collapse = ", "),
      ".\n\n",
      maintainer_dependency_hint(),
      call. = FALSE
    )
  }

  old_repos <- getOption("repos")
  on.exit(options(repos = old_repos), add = TRUE)
  if (is.null(old_repos) || identical(old_repos[["CRAN"]], "@CRAN@")) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }

  utils::install.packages(missing, quiet = TRUE)

  still_missing <- missing[
    !vapply(missing, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(still_missing) > 0) {
    stop(
      "Unable to install required replication dependencies: ",
      paste(still_missing, collapse = ", ")
    )
  }

  invisible(TRUE)
}

#' Retry an expression after installing a missing package
#'
#' @param expr Expression to evaluate.
#' @param install_missing Logical. Whether package installation is allowed.
#' @param max_attempts Maximum number of attempts.
#'
#' @keywords internal
retry_with_missing_package <- function(
  expr,
  install_missing = FALSE,
  max_attempts = 2
) {
  attempt <- 1L
  repeat {
    result <- tryCatch(
      eval.parent(substitute(expr)),
      error = function(e) e
    )

    if (!inherits(result, "error")) {
      return(result)
    }

    missing_package <- extract_missing_package(result)
    if (is.null(missing_package) || !install_missing || attempt >= max_attempts) {
      stop(result)
    }

    old_repos <- getOption("repos")
    on.exit(options(repos = old_repos), add = TRUE)
    if (is.null(old_repos) || identical(old_repos[["CRAN"]], "@CRAN@")) {
      options(repos = c(CRAN = "https://cloud.r-project.org"))
    }

    utils::install.packages(missing_package, quiet = TRUE)

    if (!requireNamespace(missing_package, quietly = TRUE)) {
      stop(result)
    }

    attempt <- attempt + 1L
  }
}

#' @keywords internal
extract_missing_package <- function(error) {
  message_text <- conditionMessage(error)
  patterns <- c(
    "there is no package called [\u2018']([^\u2019']+)[\u2019']",
    "package [\u2018']([^\u2019']+)[\u2019'] not found",
    "there is no package called \"([^\"]+)\"",
    "there is no package called '([^']+)'"
  )

  for (pattern in patterns) {
    match <- regexec(pattern, message_text, perl = TRUE)
    parts <- regmatches(message_text, match)[[1]]
    if (length(parts) > 1) {
      return(parts[[2]])
    }
  }

  NULL
}

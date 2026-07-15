# Shiny feedback helpers
#
# Feedback form + CSV logging are controlled by deploy bake / deploy-options.R
# from save_local_shiny(feedback_enabled = ...). Interactive run_shiny_app()
# leaves feedback OFF by default. GitHub issue links keep hardcoded fallbacks
# when package helpers are missing from a stale worker. See FEEDBACK_TODO.md.

#' Allowed Shiny feedback categories
#'
#' @keywords internal
SHINY_FEEDBACK_CATEGORIES <- c("bug", "feature", "other")

#' Default GitHub repo for Shiny feedback issue links
#'
#' @keywords internal
SHINY_FEEDBACK_GITHUB_REPO <- "replicate-anything/replicateEverything"

#' Whether the in-app Shiny feedback form (text box + submit) is enabled
#'
#' Prefers \code{options(replicate_shiny.feedback_in_app_enabled)}. When that
#' option is unset, follows \code{replicate_shiny.feedback_enabled} (set by
#' [save_local_shiny()] / \code{deploy-options.R}). Interactive
#' [run_shiny_app()] defaults leave both unset/FALSE so the form stays off.
#'
#' @return Logical scalar.
#' @keywords internal
shiny_feedback_in_app_enabled <- function() {
  in_app <- getOption("replicate_shiny.feedback_in_app_enabled", NULL)
  if (!is.null(in_app)) {
    return(isTRUE(in_app))
  }
  isTRUE(getOption("replicate_shiny.feedback_enabled", FALSE))
}

#' Sanitize free-text Shiny feedback input
#'
#' Strips HTML tags and control characters; trims and caps length. Returns plain
#' text only (never evaluated or rendered as HTML).
#'
#' @param text Character scalar.
#' @param max_chars Maximum length after sanitization.
#' @return Sanitized character scalar.
#' @keywords internal
sanitize_shiny_feedback_text <- function(text, max_chars = 2000L) {
  if (is.null(text) || length(text) != 1L) {
    return("")
  }
  text <- as.character(text)
  text <- gsub("<[^>]+>", "", text, perl = TRUE)
  text <- gsub("[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]", "", text, perl = TRUE)
  text <- trimws(text)
  max_chars <- as.integer(max_chars[[1L]] %||% max_chars)
  if (!is.finite(max_chars) || max_chars < 1L) {
    max_chars <- 2000L
  }
  if (nchar(text) > max_chars) {
    text <- substr(text, 1L, max_chars)
  }
  text
}

#' Sanitize optional feedback email
#'
#' @param email Character scalar (may be empty).
#' @param max_chars Maximum length after sanitization.
#' @return Sanitized character scalar.
#' @keywords internal
sanitize_shiny_feedback_email <- function(email, max_chars = 254L) {
  if (is.null(email) || length(email) != 1L) {
    return("")
  }
  email <- trimws(as.character(email))
  email <- gsub("<[^>]+>", "", email, perl = TRUE)
  email <- gsub("[\u0001-\u001F\u007F]", "", email, perl = TRUE)
  max_chars <- as.integer(max_chars[[1L]] %||% max_chars)
  if (!is.finite(max_chars) || max_chars < 1L) {
    max_chars <- 254L
  }
  if (nchar(email) > max_chars) {
    email <- substr(email, 1L, max_chars)
  }
  email
}

#' Validate a Shiny feedback category against the allowlist
#'
#' @param category Character scalar.
#' @return Allowlisted category, or `NA_character_` when invalid.
#' @keywords internal
validate_shiny_feedback_category <- function(category) {
  cat <- tolower(trimws(as.character(category)))
  if (!nzchar(cat) || !cat %in% SHINY_FEEDBACK_CATEGORIES) {
    return(NA_character_)
  }
  cat
}

#' Default relative path for server-side Shiny feedback CSV
#'
#' Relative to the Shiny app working directory (deploy dir on shiny2.wzb.eu).
#'
#' @keywords internal
SHINY_FEEDBACK_DEFAULT_FILE <- "data/feedback.csv"

#' Whether server-side Shiny feedback CSV logging is enabled
#'
#' Returns \code{FALSE} unless explicitly enabled via
#' \code{REPLICATE_SHINY_FEEDBACK_ENABLED=1} or
#' \code{options(replicate_shiny.feedback_enabled = TRUE)}.
#'
#' @return Logical scalar.
#' @keywords internal
shiny_feedback_log_enabled <- function() {
  env <- Sys.getenv("REPLICATE_SHINY_FEEDBACK_ENABLED", unset = "")
  if (length(env) == 1L && nzchar(env)) {
    return(tolower(env) %in% c("1", "true", "yes", "on"))
  }
  isTRUE(getOption("replicate_shiny.feedback_enabled", FALSE))
}

#' Resolve configured Shiny feedback CSV path (relative or absolute)
#'
#' Reads \code{REPLICATE_SHINY_FEEDBACK_FILE} or
#' \code{options(replicate_shiny.feedback_file)}; default
#' \code{data/feedback.csv}.
#'
#' @return Character scalar file path.
#' @keywords internal
shiny_feedback_file <- function() {
  env <- Sys.getenv("REPLICATE_SHINY_FEEDBACK_FILE", unset = "")
  if (length(env) == 1L && nzchar(env)) {
    return(as.character(env))
  }
  opt <- getOption("replicate_shiny.feedback_file", SHINY_FEEDBACK_DEFAULT_FILE)
  as.character(opt)
}

#' Resolve Shiny feedback CSV to an absolute path
#'
#' Relative paths are resolved against [shiny_deploy_dir()] (the Shiny app
#' deploy directory on shiny2.wzb.eu, e.g. \code{.../ipi/replicate/data/feedback.csv}),
#' not the process working directory when they differ.
#'
#' @return Normalized absolute file path.
#' @keywords internal
shiny_feedback_file_path <- function() {
  file <- shiny_feedback_file()
  if (.is_abs_path_shiny_feedback(file)) {
    return(normalizePath(file, winslash = "/", mustWork = FALSE))
  }
  normalizePath(
    file.path(shiny_deploy_dir(), file),
    winslash = "/",
    mustWork = FALSE
  )
}

#' @keywords internal
.is_abs_path_shiny_feedback <- function(path) {
  path <- as.character(path)
  grepl("^/", path) || grepl("^[A-Za-z]:[/\\\\]", path)
}

#' Escape one field for Shiny feedback CSV output
#'
#' Prefixes formula-injection starters with a single quote; quotes fields that
#' contain commas, quotes, or newlines.
#'
#' @param x Character scalar.
#' @return Escaped character scalar.
#' @keywords internal
escape_shiny_feedback_csv_field <- function(x) {
  x <- as.character(x)
  if (nzchar(x) && substr(x, 1L, 1L) %in% c("=", "+", "-", "@", "\t", "\r")) {
    x <- paste0("'", x)
  }
  if (grepl("[,\r\n\"]", x, perl = TRUE)) {
    x <- paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")
  }
  x
}

#' Label and title prefix for a feedback category
#'
#' @param category Allowlisted category.
#' @return Named list with \code{label} and \code{title_prefix}.
#' @keywords internal
shiny_feedback_category_meta <- function(category) {
  switch(
    category,
    bug = list(label = "bug", title_prefix = "[Bug] "),
    feature = list(label = "enhancement", title_prefix = "[Feature] "),
    other = list(label = character(0), title_prefix = "[Feedback] ")
  )
}

#' Build a GitHub new-issue URL for Shiny feedback
#'
#' @param category Allowlisted category (\code{bug}, \code{feature}, \code{other}).
#' @param text Sanitized plain-text body.
#' @param email Optional sanitized contact email.
#' @param repo GitHub \code{owner/repo} slug.
#' @return Character URL, or \code{""} when the category is invalid.
#' @keywords internal
shiny_feedback_github_issue_url <- function(
  category,
  text,
  email = NULL,
  repo = "replicate-anything/replicateEverything"
) {
  category <- validate_shiny_feedback_category(category)
  if (is.na(category) || !nzchar(text)) {
    return("")
  }
  meta <- shiny_feedback_category_meta(category)
  title_seed <- gsub("\\s+", " ", text)
  title <- paste0(meta$title_prefix, title_seed)
  if (nchar(title) > 120L) {
    title <- paste0(substr(title, 1L, 117L), "...")
  }
  body_parts <- c(
    text,
    if (!is.null(email) && nzchar(email)) {
      paste0("\n\n---\nContact (optional): ", email)
    },
    "\n\n---\nSubmitted via replicateEverything Shiny app."
  )
  body <- paste(body_parts, collapse = "")
  params <- list(
    title = title,
    body = body
  )
  if (length(meta$label) > 0L && nzchar(meta$label)) {
    params$labels <- meta$label
  }
  qs <- paste(
    names(params),
    vapply(params, utils::URLencode, FUN.VALUE = character(1L), reserved = TRUE),
    sep = "=",
    collapse = "&"
  )
  paste0("https://github.com/", repo, "/issues/new?", qs)
}

#' Build a category-only GitHub new-issue URL (no user body)
#'
#' @param category Allowlisted category.
#' @param repo GitHub \code{owner/repo} slug.
#' @return Character URL.
#' @keywords internal
shiny_feedback_github_category_url <- function(
  category,
  repo = "replicate-anything/replicateEverything"
) {
  category <- validate_shiny_feedback_category(category)
  if (is.na(category)) {
    return(paste0("https://github.com/", repo, "/issues/new"))
  }
  meta <- shiny_feedback_category_meta(category)
  params <- list(title = meta$title_prefix)
  if (length(meta$label) > 0L && nzchar(meta$label)) {
    params$labels <- meta$label
  }
  qs <- paste(
    names(params),
    vapply(params, utils::URLencode, FUN.VALUE = character(1L), reserved = TRUE),
    sep = "=",
    collapse = "&"
  )
  paste0("https://github.com/", repo, "/issues/new?", qs)
}

#' @rdname shiny_feedback_github_category_url
#' @keywords internal
shiny_feedback_category_url <- shiny_feedback_github_category_url

#' Hardcoded GitHub new-issue URL when package helpers are unavailable
#'
#' Used by the Shiny Feedback tab when \code{shiny_feedback_github_category_url}
#' is missing from a stale worker namespace (no dynamic package lookup).
#'
#' @param category Allowlisted category.
#' @param repo GitHub \code{owner/repo} slug.
#' @return Character URL.
#' @keywords internal
shiny_feedback_github_category_url_fallback <- function(
  category,
  repo = SHINY_FEEDBACK_GITHUB_REPO
) {
  category <- validate_shiny_feedback_category(category)
  base <- paste0("https://github.com/", repo, "/issues/new")
  if (is.na(category)) {
    return(base)
  }
  meta <- shiny_feedback_category_meta(category)
  params <- list(title = meta$title_prefix)
  if (length(meta$label) > 0L && nzchar(meta$label)) {
    params$labels <- meta$label
  }
  qs <- paste(
    names(params),
    vapply(params, utils::URLencode, FUN.VALUE = character(1L), reserved = TRUE),
    sep = "=",
    collapse = "&"
  )
  paste0(base, "?", qs)
}

#' Safe GitHub category URL (package helper or hardcoded fallback)
#'
#' Never errors when \code{shiny_feedback_github_category_url} is missing.
#'
#' @param category Allowlisted category.
#' @param repo GitHub \code{owner/repo} slug.
#' @return Character URL.
#' @keywords internal
shiny_feedback_category_url_safe <- function(
  category,
  repo = SHINY_FEEDBACK_GITHUB_REPO
) {
  ns <- tryCatch(asNamespace("replicateEverything"), error = function(e) NULL)
  if (!is.null(ns)) {
    for (nm in c("shiny_feedback_github_category_url", "shiny_feedback_category_url")) {
      if (exists(nm, envir = ns, inherits = FALSE)) {
        fn <- get(nm, envir = ns, inherits = FALSE)
        return(fn(category, repo = repo))
      }
    }
  }
  shiny_feedback_github_category_url_fallback(category, repo = repo)
}

#' Append one sanitized feedback record to the server CSV log
#'
#' Writes to \code{data/feedback.csv} by default (relative to the Shiny app
#' deploy directory). Creates the parent \code{data/} directory when needed.
#' Columns: \code{timestamp}, \code{category}, \code{email}, \code{text}.
#'
#' @param category Allowlisted category.
#' @param text Sanitized plain-text feedback.
#' @param email Optional sanitized email.
#' @param file CSV path; default from [shiny_feedback_file_path()].
#' @return Logical: \code{TRUE} when written.
#' @keywords internal
append_shiny_feedback_log <- function(
  category,
  text,
  email = NULL,
  file = shiny_feedback_file_path()
) {
  category <- validate_shiny_feedback_category(category)
  if (is.na(category) || !nzchar(text)) {
    return(FALSE)
  }
  if (is.null(file) || !length(file) || !nzchar(file)) {
    return(FALSE)
  }
  parent <- dirname(file)
  if (!dir.exists(parent)) {
    dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(parent)) {
    return(FALSE)
  }
  row <- c(
    format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    category,
    if (!is.null(email) && nzchar(email)) email else "",
    text
  )
  line <- paste(
    vapply(row, escape_shiny_feedback_csv_field, FUN.VALUE = character(1L)),
    collapse = ","
  )
  new_file <- !file.exists(file)
  con <- file(file, open = if (new_file) "w" else "a", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  if (new_file) {
    writeLines("timestamp,category,email,text", con, useBytes = TRUE)
  }
  writeLines(line, con, useBytes = TRUE)
  invisible(TRUE)
}

#' Cooldown seconds between in-app feedback submissions
#'
#' @keywords internal
SHINY_FEEDBACK_COOLDOWN_SECS <- 30L

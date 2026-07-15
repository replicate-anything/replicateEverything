#' Allowed Shiny feedback categories
#'
#' @keywords internal
SHINY_FEEDBACK_CATEGORIES <- c("bug", "feature", "other")

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

#' Resolve configured Shiny feedback log directory
#'
#' Reads \code{REPLICATE_SHINY_FEEDBACK_DIR} or
#' \code{options(replicate_shiny.feedback_dir)}.
#'
#' @return Normalized directory path, or `NULL` when unset.
#' @keywords internal
shiny_feedback_log_dir <- function() {
  env <- Sys.getenv("REPLICATE_SHINY_FEEDBACK_DIR", unset = "")
  if (length(env) == 1L && nzchar(env)) {
    return(normalizePath(env, winslash = "/", mustWork = FALSE))
  }
  opt <- getOption("replicate_shiny.feedback_dir", NULL)
  if (!is.null(opt) && length(opt) == 1L && nzchar(as.character(opt))) {
    return(normalizePath(as.character(opt), winslash = "/", mustWork = FALSE))
  }
  NULL
}

#' Whether server-side Shiny feedback logging is enabled
#'
#' @return Logical scalar.
#' @keywords internal
shiny_feedback_log_enabled <- function() {
  dir <- shiny_feedback_log_dir()
  !is.null(dir) && nzchar(dir)
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

#' Append one sanitized feedback record to the server log
#'
#' @param category Allowlisted category.
#' @param text Sanitized plain-text feedback.
#' @param email Optional sanitized email.
#' @param dir Log directory; default from [shiny_feedback_log_dir()].
#' @return Logical: \code{TRUE} when written.
#' @keywords internal
append_shiny_feedback_log <- function(
  category,
  text,
  email = NULL,
  dir = shiny_feedback_log_dir()
) {
  category <- validate_shiny_feedback_category(category)
  if (is.na(category) || !nzchar(text)) {
    return(FALSE)
  }
  if (is.null(dir) || !length(dir) || !nzchar(dir)) {
    return(FALSE)
  }
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(dir)) {
    return(FALSE)
  }
  log_file <- file.path(dir, "shiny-feedback.log")
  record <- list(
    ts = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    category = category,
    email = if (!is.null(email) && nzchar(email)) email else "",
    text = text
  )
  line <- jsonlite::toJSON(record, auto_unbox = TRUE)
  con <- file(log_file, open = "a", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(line, con, useBytes = TRUE)
  invisible(TRUE)
}

#' Cooldown seconds between in-app feedback submissions
#'
#' @keywords internal
SHINY_FEEDBACK_COOLDOWN_SECS <- 30L

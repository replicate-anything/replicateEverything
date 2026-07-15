test_that("all Shiny feedback helpers referenced from app.R exist in namespace", {
  skip_if_not_installed("replicateEverything")
  ns <- asNamespace("replicateEverything")
  feedback_refs <- c(
    "SHINY_FEEDBACK_COOLDOWN_SECS",
    "validate_shiny_feedback_category",
    "sanitize_shiny_feedback_text",
    "sanitize_shiny_feedback_email",
    "shiny_feedback_log_enabled",
    "append_shiny_feedback_log",
    "shiny_feedback_github_issue_url",
    "shiny_feedback_github_category_url",
    "shiny_feedback_category_url"
  )
  missing <- feedback_refs[!vapply(
    feedback_refs,
    function(nm) exists(nm, envir = ns, inherits = FALSE),
    FUN.VALUE = logical(1L)
  )]
  expect_equal(missing, character(0))
})

test_that("sanitize_shiny_feedback_text strips HTML and control characters", {
  raw <- paste0(
    "<script>alert('x')</script>",
    "Hello\u0001world",
    "\nLine two"
  )
  out <- sanitize_shiny_feedback_text(raw)
  expect_false(grepl("<", out, fixed = TRUE))
  expect_false(grepl("\u0001", out, fixed = TRUE))
  expect_true(grepl("Hello", out, fixed = TRUE))
  expect_true(grepl("Line two", out, fixed = TRUE))
})

test_that("sanitize_shiny_feedback_text enforces max length", {
  long <- paste(rep("a", 3000L), collapse = "")
  out <- sanitize_shiny_feedback_text(long, max_chars = 2000L)
  expect_equal(nchar(out), 2000L)
})

test_that("validate_shiny_feedback_category accepts allowlist only", {
  expect_equal(validate_shiny_feedback_category("bug"), "bug")
  expect_equal(validate_shiny_feedback_category(" FEATURE "), "feature")
  expect_equal(validate_shiny_feedback_category("other"), "other")
  expect_true(is.na(validate_shiny_feedback_category("spam")))
  expect_true(is.na(validate_shiny_feedback_category("")))
})

test_that("shiny_feedback_github_category_url builds category-only issue links", {
  bug_url <- shiny_feedback_github_category_url("bug")
  expect_true(startsWith(bug_url, "https://github.com/replicate-anything/replicateEverything/issues/new?"))
  expect_true(grepl("labels=bug", bug_url, fixed = TRUE))
  expect_true(grepl("%5BBug%5D%20", bug_url, fixed = TRUE))

  feature_url <- shiny_feedback_github_category_url("feature")
  expect_true(grepl("labels=enhancement", feature_url, fixed = TRUE))

  other_url <- shiny_feedback_github_category_url("other")
  expect_false(grepl("labels=", other_url, fixed = TRUE))
  expect_true(grepl("%5BFeedback%5D%20", other_url, fixed = TRUE))

  expect_equal(shiny_feedback_category_url("bug"), bug_url)
})

test_that("shiny_feedback_github_issue_url encodes sanitized body", {
  url <- shiny_feedback_github_issue_url(
    "bug",
    "Table 1 fails to load",
    email = "user@example.org"
  )
  expect_true(startsWith(url, "https://github.com/replicate-anything/replicateEverything/issues/new?"))
  expect_true(grepl("labels=bug", url, fixed = TRUE))
  expect_true(grepl("Table%201%20fails", url, fixed = TRUE))
  expect_true(grepl("user%40example.org", url, fixed = TRUE))
})

test_that("shiny_feedback_log_enabled is false by default", {
  withr::local_envvar(c(REPLICATE_SHINY_FEEDBACK_ENABLED = ""))
  withr::local_options(list(replicate_shiny.feedback_enabled = NULL))
  expect_false(shiny_feedback_log_enabled())
})

test_that("shiny_feedback_log_enabled respects env and option", {
  withr::local_envvar(c(REPLICATE_SHINY_FEEDBACK_ENABLED = "1"))
  withr::local_options(list(replicate_shiny.feedback_enabled = NULL))
  expect_true(shiny_feedback_log_enabled())

  withr::local_envvar(c(REPLICATE_SHINY_FEEDBACK_ENABLED = ""))
  withr::local_options(list(replicate_shiny.feedback_enabled = TRUE))
  expect_true(shiny_feedback_log_enabled())
})

test_that("shiny_feedback_file defaults to data/feedback.csv", {
  withr::local_envvar(c(REPLICATE_SHINY_FEEDBACK_FILE = ""))
  withr::local_options(list(replicate_shiny.feedback_file = NULL))
  expect_equal(shiny_feedback_file(), "data/feedback.csv")
})

test_that("escape_shiny_feedback_csv_field prefixes formula starters", {
  expect_equal(escape_shiny_feedback_csv_field("=1+1"), "'=1+1")
  expect_equal(escape_shiny_feedback_csv_field("+cmd"), "'+cmd")
  expect_equal(escape_shiny_feedback_csv_field("plain"), "plain")
})

test_that("escape_shiny_feedback_csv_field quotes commas and newlines", {
  expect_equal(escape_shiny_feedback_csv_field("a,b"), "\"a,b\"")
  expect_equal(escape_shiny_feedback_csv_field("line\nbreak"), "\"line\nbreak\"")
})

test_that("append_shiny_feedback_log writes CSV with header when enabled path set", {
  root <- tempfile("shiny-feedback-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  withr::local_dir(root)
  withr::local_options(list(
    replicate_shiny.feedback_enabled = TRUE,
    replicate_shiny.feedback_file = "data/feedback.csv"
  ))

  ok <- append_shiny_feedback_log("feature", "Add export button", email = "user@example.org")
  expect_true(isTRUE(ok))

  csv_path <- file.path(root, "data", "feedback.csv")
  expect_true(file.exists(csv_path))
  lines <- readLines(csv_path, warn = FALSE)
  expect_equal(lines[[1L]], "timestamp,category,email,text")
  expect_true(grepl(",feature,user@example.org,Add export button$", lines[[2L]]))
})

test_that("append_shiny_feedback_log appends rows without repeating header", {
  root <- tempfile("shiny-feedback-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  withr::local_dir(root)
  withr::local_options(list(
    replicate_shiny.feedback_enabled = TRUE,
    replicate_shiny.feedback_file = "data/feedback.csv"
  ))

  append_shiny_feedback_log("bug", "First report")
  append_shiny_feedback_log("other", "Second report")

  lines <- readLines(file.path(root, "data", "feedback.csv"), warn = FALSE)
  expect_length(lines, 3L)
  expect_equal(lines[[1L]], "timestamp,category,email,text")
})

test_that("shiny_feedback_file_path resolves relative to replicate_shiny.app_dir", {
  app_root <- normalizePath(tempfile("shiny-appdir-"), winslash = "/", mustWork = FALSE)
  dir.create(app_root)
  on.exit(unlink(app_root, recursive = TRUE), add = TRUE)

  session_wd <- tempfile("shiny-session-wd-")
  dir.create(session_wd)
  on.exit(unlink(session_wd, recursive = TRUE), add = TRUE)

  withr::local_dir(session_wd)
  withr::local_options(list(
    replicate_shiny.app_dir = app_root,
    replicate_shiny.feedback_file = "data/feedback.csv"
  ))
  withr::local_envvar(c(REPLICATE_SHINY_FEEDBACK_FILE = ""))

  resolved <- gsub("\\\\", "/", shiny_feedback_file_path())
  expect_true(grepl("/data/feedback.csv$", resolved))
  expect_true(grepl(basename(app_root), resolved, fixed = TRUE))
  expect_false(grepl(basename(session_wd), resolved, fixed = TRUE))
})

test_that("source_shiny_deploy_config loads deploy-options.R before local.R overrides", {
  dest <- tempfile("shiny-deploy-config-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      "options(replicate_shiny.feedback_enabled = TRUE)",
      "options(replicate_shiny.feedback_file = \"data/feedback.csv\")"
    ),
    file.path(dest, "deploy-options.R"),
    useBytes = TRUE
  )
  writeLines(
    "options(replicate_shiny.feedback_enabled = FALSE)",
    file.path(dest, "local.R"),
    useBytes = TRUE
  )

  withr::local_options(list(
    replicate_shiny.feedback_enabled = NULL,
    replicate_shiny.feedback_file = NULL,
    replicate_shiny.local_r_loaded = NULL,
    replicate_shiny.deploy_config_loaded = NULL,
    replicate_shiny.app_dir = NULL
  ))
  withr::local_envvar(c(REPLICATE_SHINY_FEEDBACK_ENABLED = ""))

  source_shiny_deploy_config(dest)

  expect_false(shiny_feedback_log_enabled())
  expect_true(isTRUE(getOption("replicate_shiny.local_r_loaded")))
  expect_true(isTRUE(getOption("replicate_shiny.deploy_config_loaded")))
  expect_equal(
    normalizePath(getOption("replicate_shiny.app_dir"), winslash = "/", mustWork = FALSE),
    normalizePath(dest, winslash = "/", mustWork = FALSE)
  )
})

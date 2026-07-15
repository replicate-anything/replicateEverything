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

test_that("append_shiny_feedback_log writes JSON lines when dir is set", {
  dir <- tempfile("shiny-feedback-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  withr::local_options(list(replicate_shiny.feedback_dir = dir))
  ok <- append_shiny_feedback_log("feature", "Add export button", email = "")
  expect_true(isTRUE(ok))

  log_path <- file.path(dir, "shiny-feedback.log")
  expect_true(file.exists(log_path))
  line <- readLines(log_path, n = 1L, warn = FALSE)
  parsed <- jsonlite::fromJSON(line)
  expect_equal(parsed$category, "feature")
  expect_equal(parsed$text, "Add export button")
})

test_that("shiny_feedback_log_enabled is false without configured dir", {
  withr::local_envvar(c(REPLICATE_SHINY_FEEDBACK_DIR = ""))
  withr::local_options(list(replicate_shiny.feedback_dir = NULL))
  expect_false(shiny_feedback_log_enabled())
})

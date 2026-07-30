test_that("study replication timings round-trip", {
  root <- tempfile("timings-study-")
  dir.create(file.path(root, "outputs"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  expect_true(is.na(lookup_study_replication_timing(root, "fig_1")))
  path <- record_study_replication_timing(root, "fig_1", 12.5, engine = "stata")
  expect_true(file.exists(path))
  expect_equal(lookup_study_replication_timing(root, "fig_1"), 12.5)

  warn <- format_long_run_warning(
    timeout_seconds = 60,
    seconds = 60,
    bake_seconds = 480
  )
  expect_match(warn, "last successful bake", ignore.case = TRUE)
  expect_match(warn, "8 minute|about 8", ignore.case = TRUE)
})

test_that("record_study_replication_timing updates generated_at atomically", {
  root <- tempfile("timings-atomic-")
  dir.create(file.path(root, "outputs"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  record_study_replication_timing(root, "fig_1", 10, engine = "stata")
  record_study_replication_timing(root, "tab_1", 20, engine = "stata")
  raw <- jsonlite::fromJSON(
    study_replication_timings_path(root),
    simplifyVector = FALSE
  )
  expect_true(nzchar(raw$generated_at %||% ""))
  expect_equal(raw$steps$fig_1$seconds, 10)
  expect_equal(raw$steps$tab_1$seconds, 20)
  expect_false(file.exists(paste0(study_replication_timings_path(root), ".tmp")))
})

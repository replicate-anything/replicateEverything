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

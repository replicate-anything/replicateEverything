test_that("audit_jobs_from_replications lists each engine", {
  reps <- list(
    list(id = "tab_1", type = "table", label = "Table 1", code = "code/tab_1.R"),
    list(
      id = "tab_1_stata",
      type = "table",
      label = "Table 1",
      engine = "stata",
      code = "code/tab_1.do"
    ),
    list(id = "fig_1", type = "figure", label = "Figure 1", code = "code/fig_1.R")
  )
  jobs <- audit_jobs_from_replications(reps)
  expect_equal(nrow(jobs), 3L)
  expect_setequal(jobs$what, c("tab_1", "tab_1_stata", "fig_1"))
  expect_setequal(jobs$engine, c("r", "stata", "r"))
})

test_that("audit_error_snippet truncates long messages", {
  err <- simpleError(paste(rep("x", 400L), collapse = ""))
  out <- audit_error_snippet(err, max_chars = 50L)
  expect_equal(nchar(out), 53L)
  expect_match(out, "\\.\\.\\.$")
})

test_that("audit_everything_qmd resolves installed or dev path", {
  path <- audit_everything_qmd()
  expect_true(nzchar(path))
  expect_true(file.exists(path))
  expect_match(path, "audit_everything\\.qmd$")
})

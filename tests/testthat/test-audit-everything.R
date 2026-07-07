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
    list(id = "fig_1", type = "figure", label = "Figure 1", code = "code/fig_1.R"),
    list(id = "prep_data", type = "step", label = "Prepare data", engine = "python", code = "code/steps/prep.ipynb")
  )
  jobs <- audit_jobs_from_replications(reps)
  expect_equal(nrow(jobs), 4L)
  expect_setequal(jobs$what, c("tab_1", "tab_1_stata", "fig_1", "prep_data"))
  expect_setequal(jobs$engine, c("r", "stata", "r", "python"))
})

test_that("audit_error_snippet truncates long messages", {
  err <- simpleError(paste(rep("x", 400L), collapse = ""))
  out <- audit_error_snippet(err, max_chars = 50L)
  expect_equal(nchar(out), 53L)
  expect_match(out, "\\.\\.\\.$")
})

test_that("audit_everything_qmd resolves registry report path", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  registry_qmd <- file.path(monorepo_root, "registry", "audit_everything.qmd")
  testthat::skip_if_not(file.exists(registry_qmd), "registry audit_everything.qmd missing")

  path <- audit_everything_qmd(file.path(monorepo_root, "registry"))
  expect_true(nzchar(path))
  expect_equal(normalizePath(path, winslash = "/"), normalizePath(registry_qmd, winslash = "/"))
})

test_that("registry audit summary paths resolve under registry root", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  registry_root <- file.path(monorepo_root, "registry")
  testthat::skip_if_not(dir.exists(registry_root), "registry folder missing")

  expect_equal(
    basename(registry_audit_summary_path(registry_root)),
    "audit_summary.json"
  )
  expect_equal(
    basename(registry_audit_rds_path(registry_root)),
    "audit_latest.rds"
  )
})

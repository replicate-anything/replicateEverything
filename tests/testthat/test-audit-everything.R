test_that("audit_runtime_category buckets short/medium/slow", {
  expect_equal(audit_runtime_category(5), "short")
  expect_equal(audit_runtime_category(29.9), "short")
  expect_equal(audit_runtime_category(30), "medium")
  expect_equal(audit_runtime_category(299), "medium")
  expect_equal(audit_runtime_category(300), "slow")
  expect_equal(audit_runtime_category(NA_real_), NA_character_)
  expect_equal(
    audit_runtime_category(c(1, 60, 600)),
    c("short", "medium", "slow")
  )
})

test_that("audit_runtime_advice describes categories", {
  expect_match(audit_runtime_advice("short", 12), "seconds")
  expect_match(audit_runtime_advice("short", 12), "12s")
  expect_match(audit_runtime_advice("short", 0.3), "0\\.3s")
  expect_false(grepl("last audit: 0s", audit_runtime_advice("short", 0.3), fixed = TRUE))
  expect_match(audit_runtime_advice("medium", 90), "minute")
  expect_match(audit_runtime_advice("slow", 400), "minutes")
  expect_equal(audit_runtime_advice(NA_character_), "")
})

test_that("lookup_replication_audit_runtime reads snapshot rows", {
  root <- tempfile("audit-runtime-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  results <- data.frame(
    doi = "10.9999/example",
    title = "Example",
    object = "tab_1",
    object_label = "Table 1",
    type = "table",
    engine = "r",
    success = TRUE,
    run_ok = TRUE,
    substantive_ok = NA,
    seconds = 12.5,
    runtime_category = "short",
    timed_out = FALSE,
    error_snippet = "",
    stringsAsFactors = FALSE
  )
  audit <- structure(
    list(
      patience = 20,
      started_at = Sys.time(),
      finished_at = Sys.time(),
      results = results,
      summary = list(studies = 1L, runs = 1L, success = 1L, failed = 0L, timed_out = 0L)
    ),
    class = "audit_everything"
  )
  saveRDS(audit, file.path(root, "audit_latest.rds"))

  # Clear session cache so the temp snapshot is used
  if (exists(".registry_audit_cache", envir = asNamespace("replicateEverything"), inherits = FALSE)) {
    cache <- get(".registry_audit_cache", envir = asNamespace("replicateEverything"))
    rm(list = ls(envir = cache), envir = cache)
  }

  hit <- lookup_replication_audit_runtime(
    "10.9999/example",
    "tab_1",
    engine = "r",
    registry_root = root
  )
  expect_true(hit$available)
  expect_equal(hit$runtime_category, "short")
  expect_equal(hit$seconds, 12.5)
  expect_match(hit$advice, "seconds")
})

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

test_that("filter_index_by_collections keeps rows with matching tags", {
  index <- data.frame(
    folder = c("a", "b", "c"),
    collections = c("APSR", "World Bank|PED", ""),
    stringsAsFactors = FALSE
  )
  out <- filter_index_by_collections(index, "APSR")
  expect_equal(nrow(out), 1L)
  expect_equal(out$folder, "a")

  out2 <- filter_index_by_collections(index, c("PED", "IPI"))
  expect_equal(nrow(out2), 1L)
  expect_equal(out2$folder, "b")

  expect_equal(nrow(filter_index_by_collections(index, NULL)), 3L)
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

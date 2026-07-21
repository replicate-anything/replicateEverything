test_that("check_glm_table_benchmark accepts matching glm list", {
  df <- data.frame(
    x = rep(c(-1, 1), each = 50),
    y = c(rep(0, 40), rep(1, 10), rep(1, 40), rep(0, 10))
  )
  m <- glm(y ~ x, data = df, family = binomial())
  spec <- list(
    terms = "x",
    coef = unname(coef(m)["x"]),
    se = sqrt(unname(vcov(m)["x", "x"])),
    nobs = stats::nobs(m)
  )
  expect_true(check_glm_table_benchmark(list(m), spec, tolerance = 1e-6))
})

test_that("check_glm_table_benchmark rejects coefficient mismatch", {
  df <- data.frame(x = rep(c(-1, 1), each = 50), y = rbinom(100, 1, 0.5))
  m <- glm(y ~ x, data = df, family = binomial())
  spec <- list(
    terms = "x",
    coef = unname(coef(m)["x"]) + 1,
    se = sqrt(unname(vcov(m)["x", "x"])),
    nobs = stats::nobs(m)
  )
  expect_error(
    check_glm_table_benchmark(list(m), spec, tolerance = 0.001),
    "Published benchmark check failed"
  )
})

test_that("load_substantive_check_fn injects glm benchmark helper", {
  study_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "rep-10.1017-S0003055403000534"),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(dir.exists(study_root), "F&L study repo missing")
  skip_if_not(
    file.exists(file.path(study_root, "tests/substantive/tab_1.R")),
    "substantive check missing"
  )

  fn <- load_substantive_check_fn(study_root, "tab_1")
  expect_true(is.function(fn))
  df <- data.frame(
    x = rep(c(-1, 1), each = 50),
    y = c(rep(0, 40), rep(1, 10), rep(1, 40), rep(0, 10))
  )
  m <- glm(y ~ x, data = df, family = binomial())
  bad <- tryCatch(
    fn(list(m)),
    error = function(e) e
  )
  expect_s3_class(bad, "error")
  expect_no_match(conditionMessage(bad), "could not find function")
  expect_match(conditionMessage(bad), "Expected 5 models")
})

test_that("run_substantive_check loads study check script", {
  study_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "rep-10.1017-S0003055403000534"),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(dir.exists(study_root), "F&L study repo missing")
  skip_if_not(
    file.exists(file.path(study_root, "tests/substantive/tab_1.R")),
    "substantive check missing"
  )

  df <- data.frame(
    x = rep(c(-1, 1), each = 50),
    y = c(rep(0, 40), rep(1, 10), rep(1, 40), rep(0, 10))
  )
  m <- glm(y ~ x, data = df, family = binomial())
  bad <- run_substantive_check(
    list(m),
    doi = "10.1017/S0003055403000534",
    what = "tab_1",
    study_root = study_root
  )
  expect_true(bad$checked)
  expect_false(bad$ok)
})

test_that("check_replication reports substantive check coverage", {
  with_fixture_opts({
    study_dir <- file.path(
      getOption("replicateEverything.study_folders_root"),
      "rep-10.9999-example"
    )
    skip_if_not(dir.exists(study_dir), "fixture study repo missing")
    result <- check_replication(
      study_dir,
      full_replication = FALSE,
      registry_root = getOption("replicateEverything.registry_root")
    )
    substantive <- result$checks[grepl("^substantive_", result$checks$check), , drop = FALSE]
    expect_gt(nrow(substantive), 0L)
    expect_true(all(substantive$passed))
    expect_true(any(grepl("Recommended: tests/substantive/", substantive$message)))
  })
})

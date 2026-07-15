test_that("preview_data_file returns head for RDS data frames", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  df <- data.frame(a = 1:10, b = letters[1:10])
  saveRDS(df, tmp)

  preview <- replicateEverything:::preview_data_file(tmp)
  expect_s3_class(preview, "data.frame")
  expect_equal(nrow(preview), 6L)
  expect_equal(ncol(preview), 2L)
})

test_that("resolve_prep_display_object promotes RDS path preview", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  df <- data.frame(x = 1:8, y = letters[1:8])
  saveRDS(df, tmp)

  preview <- structure(
    list(path = tmp, note = "RDS output: example.rds"),
    class = "prep_output_preview"
  )
  resolved <- replicateEverything:::resolve_prep_display_object(preview)
  expect_s3_class(resolved, "data.frame")
  expect_equal(nrow(resolved), 6L)
})

test_that("resolve_prep_display_object unwraps replication_result data frames", {
  df <- data.frame(col = 1:12)
  result <- structure(
    list(object = df, output_path = "/tmp/out.rds"),
    class = "replication_result"
  )
  resolved <- replicateEverything:::resolve_prep_display_object(result)
  expect_s3_class(resolved, "data.frame")
  expect_equal(nrow(resolved), 6L)
})

test_that("prep_step_display_caption formats label and description", {
  prep <- list(
    id = "analysis_data",
    label = "Analysis data",
    description = "Rename lpopl1 and recode onset indicators for analysis"
  )
  expect_equal(
    replicateEverything:::prep_step_display_caption(prep),
    "`Analysis data` step (Rename lpopl1 and recode onset indicators for analysis)"
  )
})

test_that("load_artifact returns data frame preview for Fearon analysis_data", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-S0003055403000534")
  rds_path <- file.path(study_dir, "outputs", "analysis_data.rds")
  testthat::skip_if_not(dir.exists(study_dir), "Fearon study repo missing")
  testthat::skip_if_not(file.exists(rds_path), "analysis_data.rds missing (run prep step first)")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  loaded <- load_artifact("10.1017/S0003055403000534", "analysis_data", folder = basename(study_dir))
  expect_s3_class(loaded, "data.frame")
  expect_lte(nrow(loaded), 6L)
})

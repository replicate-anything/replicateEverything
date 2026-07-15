test_that("summarize_dataverse_deposit reports manifest paths for Velez study", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-s0003055426101622")
  testthat::skip_if_not(dir.exists(study_dir), "Velez study repo missing")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  meta <- get_replication_meta("10.1017/S0003055426101622")
  ctx <- paper_context("10.1017/S0003055426101622")
  prep <- find_prep_entry(meta, "access_deposit")
  summary <- summarize_dataverse_deposit(meta, ctx, prep = prep)

  expect_s3_class(summary, "dataverse_deposit_summary")
  expect_gt(summary$n_expected, 0L)
  expect_true(any(grepl("study1.csv", summary$expected_paths, fixed = TRUE)))
  expect_match(format(summary), "Dataverse deposit access")
  expect_match(format(summary), "Manifest paths:")
})

test_that("load_artifact returns dataverse summary for access_deposit display", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-s0003055426101622")
  testthat::skip_if_not(dir.exists(study_dir), "Velez study repo missing")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  loaded <- load_artifact("10.1017/S0003055426101622", "access_deposit")
  expect_s3_class(loaded, "dataverse_deposit_summary")
})

test_that("load_artifact summarizes prep_studies RDS for display", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-s0003055426101622")
  rds_path <- file.path(study_dir, "outputs", "prep_studies", "studies.rds")
  testthat::skip_if_not(file.exists(rds_path), "Velez prep_studies output missing")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  loaded <- load_artifact("10.1017/S0003055426101622", "prep_studies")
  expect_s3_class(loaded, "prep_output_preview")
  expect_true(!is.null(loaded$note))
  expect_match(loaded$note, "RDS output:")
  expect_match(loaded$note, "wave1_s1")
})

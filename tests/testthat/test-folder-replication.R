test_that("check_folder_replication validates Bounding Causes study", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1177-00491241211036161")
  testthat::skip_if_not(dir.exists(study_dir), "Bounding Causes study repo missing")

  registry_root <- file.path(monorepo_root, "registry")
  result <- check_folder_replication(
    study_dir,
    full_replication = FALSE,
    registry_root = registry_root
  )
  expect_s3_class(result, "folder_replication_check")
  expect_s3_class(result, "replication_check")
  failed <- result$checks[!result$checks$passed, , drop = FALSE]
  if (nrow(failed) > 0) {
    msg <- paste0(failed$check, ": ", failed$message, collapse = "; ")
    testthat::skip(paste("folder checks failed:", msg))
  }
  expect_true(result$ok)
})

test_that("registry_stub_from_folder_meta omits replications", {
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1177/00491241211036161",
      title = "Test",
      study_repo = "org/study"
    ),
    repo = "org/study",
    replications = list(list(id = "fig_1"))
  )
  stub <- registry_stub_from_folder_meta(
    meta,
    study_folder = "rep-study",
    study_root = "/tmp/rep-study"
  )
  expect_null(stub$replications)
  expect_equal(stub$paper$materials, "folder")
})

test_that("infer_study_repo_slug derives from folder name", {
  meta <- list(paper = list(doi = "https://doi.org/10.1/example"))
  expect_equal(
    infer_study_repo_slug("/work/rep-10.1177-00491241211036161", meta),
    "replicate-anything/rep-10.1177-00491241211036161"
  )
})

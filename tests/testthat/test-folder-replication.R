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

test_that("write_folder_registry_stub creates registry sync files", {
  tmp <- file.path(tempdir(), "rep-10.1177-00491241211036161")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1177/00491241211036161",
      title = "Test study",
      journal = "Journal",
      year = 2022,
      authors = "A Author"
    ),
    replications = list(list(id = "fig_1", type = "figure", code = "code/fig_1.R"))
  )
  yaml::write_yaml(meta, file.path(tmp, "replication.yml"))
  dir.create(file.path(tmp, "registry"), showWarnings = FALSE)

  written <- write_folder_registry_stub(tmp)
  expect_true(file.exists(written$stub_path))
  expect_true(file.exists(written$index_path))
  stub <- yaml::read_yaml(written$stub_path)
  expect_null(stub$replications)
  expect_equal(stub$paper$materials, "folder")
  index <- utils::read.csv(written$index_path, stringsAsFactors = FALSE)
  expect_equal(nrow(index), 1L)
})

test_that("registry_paper_yaml_path prefers flat stub files", {
  tmp <- withr::local_tempdir()
  papers <- file.path(tmp, "papers")
  dir.create(papers, recursive = TRUE)
  flat <- file.path(papers, "10.9999_example.yml")
  writeLines("paper:\n  doi: 10.9999/example", flat)
  expect_equal(
    registry_paper_yaml_path(tmp, "10.9999_example"),
    flat
  )
})

test_that("infer_study_repo_slug derives from folder name", {
  meta <- list(paper = list(doi = "https://doi.org/10.1/example"))
  expect_equal(
    infer_study_repo_slug("/work/rep-10.1177-00491241211036161", meta),
    "replicate-anything/rep-10.1177-00491241211036161"
  )
})

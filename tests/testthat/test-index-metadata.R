test_that("ensure_index_handles adds metadata columns", {
  idx <- data.frame(
    folder = "10.1177_00491241211036161",
    doi = "https://doi.org/10.1177/00491241211036161",
    title = "Test",
    journal = "",
    year = 2022L,
    authors = "Macartan Humphreys",
    repo = "replicate-anything/rep-test",
    stringsAsFactors = FALSE
  )
  out <- replicateEverything:::ensure_index_handles(idx)
  expect_true(all(c(
    "handle", "collections", "maintainer_name", "maintainer_email", "languages"
  ) %in% names(out)))
  expect_equal(out$handle[[1]], "10.1177_00491241211036161")
})

test_that("folder_registry_index_row exports maintainer collections languages", {
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1177/00491241211036161",
      title = "Bounding Causes",
      journal = "SMR",
      year = 2022L,
      authors = "Macartan Humphreys"
    ),
    repo = "replicate-anything/rep-10.1177-00491241211036161",
    maintainer = list(
      name = "Macartan Humphreys",
      email = "macartan.humphreys@wzb.eu"
    ),
    collections = c("IPI"),
    languages = list("r"),
    replications = list(
      list(id = "fig_1", engine = "r", code = "code/fig_1.R")
    )
  )
  study_root <- file.path(tempdir(), "rep-10.1177-00491241211036161")
  dir.create(study_root, showWarnings = FALSE, recursive = TRUE)
  row <- replicateEverything:::folder_registry_index_row(meta, study_root)
  expect_equal(row$collections[[1]], "IPI")
  expect_equal(row$maintainer_email[[1]], "macartan.humphreys@wzb.eu")
  expect_equal(row$languages[[1]], "r")
})

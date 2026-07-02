test_that("resolve_study_data_file finds data beside app root", {
  app_root <- tempfile("shiny-app-")
  study_root <- tempfile("study-root-")
  dir.create(file.path(app_root, "data", "rep-10.1596-1813-9450-10626"), recursive = TRUE)
  dir.create(file.path(study_root, "data"), recursive = TRUE)
  on.exit({
    unlink(app_root, recursive = TRUE)
    unlink(study_root, recursive = TRUE)
  }, add = TRUE)

  data_file <- file.path(
    app_root,
    "data",
    "rep-10.1596-1813-9450-10626",
    "ACS2017-2021_finalready.dta"
  )
  writeLines("fake", data_file)

  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1596/1813-9450-10626",
      study_folder = "rep-10.1596-1813-9450-10626"
    )
  )
  ctx <- list(
    doi = "10.1596/1813-9450-10626",
    folder = "10.1596_1813-9450-10626",
    study_data_root = app_root
  )

  rel <- "data/ACS2017-2021_finalready.dta"
  hit <- resolve_study_data_file(rel, study_root, meta, ctx)
  expect_true(hit$found)
  expect_equal(
    normalizePath(hit$path, winslash = "/", mustWork = FALSE),
    normalizePath(data_file, winslash = "/", mustWork = FALSE)
  )
})

test_that("ensure_study_data_files links external data into study_root", {
  app_root <- tempfile("shiny-app-")
  study_root <- tempfile("study-root-")
  dir.create(file.path(app_root, "data", "rep-10.1596-1813-9450-10626"), recursive = TRUE)
  on.exit({
    unlink(app_root, recursive = TRUE)
    unlink(study_root, recursive = TRUE)
  }, add = TRUE)

  source_file <- file.path(
    app_root,
    "data",
    "rep-10.1596-1813-9450-10626",
    "ACS2017-2021_finalready.dta"
  )
  writeLines("fake", source_file)

  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1596/1813-9450-10626",
      study_folder = "rep-10.1596-1813-9450-10626"
    )
  )
  ctx <- list(study_data_root = app_root)
  rel <- "data/ACS2017-2021_finalready.dta"

  ensure_study_data_files(rel, study_root, meta, ctx)
  target <- file.path(study_root, rel)
  expect_true(file.exists(target))
})

test_that("missing data reports searched paths", {
  study_root <- tempfile("study-root-")
  dir.create(study_root)
  on.exit(unlink(study_root, recursive = TRUE), add = TRUE)

  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1596/1813-9450-10626",
      study_folder = "rep-10.1596-1813-9450-10626"
    )
  )
  ctx <- list(study_data_root = study_root)

  expect_error(
    ensure_study_data_files("data/missing.dta", study_root, meta, ctx),
    "Searched:"
  )
})

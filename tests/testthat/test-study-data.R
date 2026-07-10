test_that("resolve_study_data_file finds data at data/<study>/<file>", {
  app_root <- tempfile("shiny-app-")
  study_root <- tempfile("study-root-")
  empty_monorepo <- tempfile("empty-monorepo-")
  dir.create(empty_monorepo)
  dir.create(file.path(app_root, "data", "rep-10.9999-deployed-data"), recursive = TRUE)
  on.exit({
    unlink(app_root, recursive = TRUE)
    unlink(study_root, recursive = TRUE)
    unlink(empty_monorepo, recursive = TRUE)
  }, add = TRUE)

  data_file <- file.path(
    app_root,
    "data",
    "rep-10.9999-deployed-data",
    "ACS2017-2021_finalready.dta"
  )
  writeLines("fake", data_file)

  meta <- list(
    paper = list(
      doi = "https://doi.org/10.9999/deployed-data",
      study_folder = "rep-10.9999-deployed-data"
    )
  )
  ctx <- list(study_data_root = app_root)

  rel <- "data/ACS2017-2021_finalready.dta"
  withr::with_options(
    list(replicateEverything.study_folders_root = empty_monorepo),
    {
      hit <- resolve_study_data_file(rel, study_root, meta, ctx)
      expect_true(hit$found)
      expect_equal(
        normalizePath(hit$path, winslash = "/", mustWork = FALSE),
        normalizePath(data_file, winslash = "/", mustWork = FALSE)
      )
    }
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

test_that("missing data reports working directory contents", {
  app_root <- tempfile("shiny-app-")
  study_root <- tempfile("study-root-")
  dir.create(file.path(app_root, "data", "rep-10.1596-1813-9450-10626"), recursive = TRUE)
  dir.create(study_root)
  writeLines("x", file.path(app_root, "app.R"))
  on.exit({
    unlink(app_root, recursive = TRUE)
    unlink(study_root, recursive = TRUE)
  }, add = TRUE)

  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1596/1813-9450-10626",
      study_folder = "rep-10.1596-1813-9450-10626"
    )
  )
  ctx <- list(study_data_root = app_root)

  expect_error(
    ensure_study_data_files("data/missing.dta", study_root, meta, ctx),
    "Working directory:"
  )
  expect_error(
    ensure_study_data_files("data/missing.dta", study_root, meta, ctx),
    "data/:"
  )
})

test_that("resolve_study_data_file falls back to sibling study repo data", {
  monorepo <- tempfile("monorepo-")
  cache_root <- tempfile("study-cache-")
  app_root <- tempfile("shiny-app-")
  study_name <- "rep-10.9999-siblingdata"
  dir.create(file.path(monorepo, study_name, "data"), recursive = TRUE)
  on.exit({
    unlink(monorepo, recursive = TRUE)
    unlink(cache_root, recursive = TRUE)
    unlink(app_root, recursive = TRUE)
  }, add = TRUE)

  data_file <- file.path(monorepo, study_name, "data", "sample.dta")
  writeLines("fake", data_file)
  writeLines("paper: {}", file.path(monorepo, study_name, "replication.yml"))

  meta <- list(
    paper = list(
      doi = "https://doi.org/10.9999/siblingdata",
      study_folder = study_name
    ),
    repo = "replicate-anything/rep-10.9999-siblingdata"
  )
  ctx <- list(
    doi = "10.9999/siblingdata",
    study_data_root = app_root
  )
  rel <- "data/sample.dta"

  withr::with_options(
    list(replicateEverything.study_folders_root = monorepo),
    {
      hit <- resolve_study_data_file(rel, cache_root, meta, ctx)
      expect_true(hit$found)
      expect_equal(
        normalizePath(hit$path, winslash = "/", mustWork = FALSE),
        normalizePath(data_file, winslash = "/", mustWork = FALSE)
      )
    }
  )
})

test_that("ensure_study_folder_local prefers sibling repo over github cache", {
  monorepo <- tempfile("monorepo-")
  study_dir <- file.path(monorepo, "rep-10.9999-siblingfolder")
  dir.create(study_dir, recursive = TRUE)
  on.exit(unlink(monorepo, recursive = TRUE), add = TRUE)

  meta <- list(
    paper = list(
      doi = "https://doi.org/10.9999/siblingfolder",
      title = "Test"
    ),
    repo = "replicate-anything/rep-10.9999-siblingfolder"
  )
  yaml::write_yaml(meta, file.path(study_dir, "replication.yml"))
  ctx <- list(doi = "10.9999/siblingfolder", is_folder_study = TRUE)

  withr::with_options(
    list(replicateEverything.study_folders_root = monorepo),
    {
      path <- ensure_study_folder_local(meta, ctx)
      expect_equal(
        normalizePath(path, winslash = "/", mustWork = FALSE),
        normalizePath(study_dir, winslash = "/", mustWork = FALSE)
      )
    }
  )
})

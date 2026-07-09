fixture_doi <- function() {
  "10.9999/example"
}

fixture_stata_doi <- function() {
  "10.9999/stata-fixture"
}

fixture_stata_study_root <- function() {
  normalizePath(
    file.path(testthat::test_path(".."), "fixtures", "rep-10.9999_stata"),
    winslash = "/",
    mustWork = FALSE
  )
}

fixture_stata_meta <- function() {
  yaml::read_yaml(file.path(fixture_stata_study_root(), "replication.yml"))
}

fixture_stata_index <- function() {
  data.frame(
    folder = "10.9999_stata",
    handle = "stata-fixture",
    doi = paste0("https://doi.org/", fixture_stata_doi()),
    title = "Stata Fixture Paper",
    journal = "Test Journal",
    year = 2025,
    authors = "Test Author",
    repo = "replicate-anything/rep-10.9999_stata",
    stringsAsFactors = FALSE
  )
}

with_fixture_stata_opts <- function(code) {
  fixture_root <- normalizePath(
    file.path(testthat::test_path(".."), "fixtures", "registry"),
    winslash = "/",
    mustWork = FALSE
  )
  fixtures_root <- normalizePath(
    file.path(testthat::test_path(".."), "fixtures"),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(dir.exists(fixture_root), "fixture registry missing")
  withr::with_options(
    list(
      replicateEverything.registry_root = fixture_root,
      replicateEverything.index = fixture_stata_index(),
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.study_folders_root = fixtures_root
    ),
    code
  )
}

fixture_index <- function() {
  data.frame(
    folder = "10.9999_example",
    handle = "fixture-paper",
    doi = paste0("https://doi.org/", fixture_doi()),
    title = "Fixture Paper",
    journal = "Test Journal",
    year = 2025,
    authors = "Test Author",
    repo = "replicate-anything/rep-10.9999_example",
    stringsAsFactors = FALSE
  )
}

fixture_opts <- function() {
  fixture_root <- normalizePath(
    file.path(testthat::test_path(".."), "fixtures", "registry"),
    winslash = "/",
    mustWork = FALSE
  )
  fixtures_root <- normalizePath(
    file.path(testthat::test_path(".."), "fixtures"),
    winslash = "/",
    mustWork = FALSE
  )
  list(
    replicateEverything.registry_root = fixture_root,
    replicateEverything.index = fixture_index(),
    replicateEverything.use_sibling_packages = TRUE,
    replicateEverything.study_folders_root = fixtures_root
  )
}

with_fixture_opts <- function(code) {
  opts <- fixture_opts()
  skip_if_not(dir.exists(opts$replicateEverything.registry_root), "fixture registry missing")
  withr::with_options(opts, code)
}

local_monorepo_opts <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  list(
    replicateEverything.registry_root = file.path(root, "registry"),
    replicateEverything.study_folders_root = root,
    replicateEverything.use_sibling_packages = TRUE
  )
}

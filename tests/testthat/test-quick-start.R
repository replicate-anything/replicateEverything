quick_start_doi <- "10.1177/00491241211036161"
fixture_doi <- "10.9999/example"

fixture_index <- function() {
  data.frame(
    folder = "10.9999_example",
    doi = paste0("https://doi.org/", fixture_doi),
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

test_that("quick start: get_doi_metadata returns bibliographic fields", {
  skip_on_cran()

  meta <- get_doi_metadata(quick_start_doi)
  expect_type(meta, "list")
  expect_true(nzchar(meta$title %||% ""))
})

test_that("quick start: search_papers finds registry matches", {
  opts <- fixture_opts()
  skip_if_not(dir.exists(opts$replicateEverything.registry_root), "fixture registry missing")

  withr::with_options(
    opts,
    {
      hits <- search_papers("fixture")
      expect_true(is.data.frame(hits))
      expect_true(nrow(hits) >= 1)
      expect_true(any(grepl("Fixture", hits$title, ignore.case = TRUE)))
    }
  )
})

test_that("quick start: list_replications returns registered ids", {
  opts <- fixture_opts()
  skip_if_not(dir.exists(opts$replicateEverything.registry_root), "fixture registry missing")

  withr::with_options(
    opts,
    {
      reps <- list_replications(fixture_doi)
      expect_true(length(reps) >= 1)
      ids <- vapply(reps, function(x) as.character(x$id), character(1))
      expect_true("fig_1" %in% ids)
      expect_true("tab_1" %in% ids)
    }
  )
})

test_that("quick start: run_replication returns a figure object", {
  opts <- fixture_opts()
  skip_if_not(dir.exists(opts$replicateEverything.registry_root), "fixture registry missing")

  withr::with_options(
    opts,
    {
      result <- render_replication(fixture_doi, "fig_1")
      expect_s3_class(result, "replication_result")
      obj <- replication_object(result)
      expect_true(
        inherits(obj, "ggplot") ||
          inherits(obj, "gg") ||
          inherits(obj, "data.frame")
      )
    }
  )
})

test_that("quick start: replicate_paper runs all registered replications", {
  opts <- fixture_opts()
  skip_if_not(dir.exists(opts$replicateEverything.registry_root), "fixture registry missing")

  withr::with_options(
    opts,
    {
      results <- replicate_paper(fixture_doi)
      expect_type(results, "list")
      expect_equal(length(results), 2)
      expect_true(all(vapply(results, function(x) inherits(x, "replication_result"), logical(1))))
    }
  )
})

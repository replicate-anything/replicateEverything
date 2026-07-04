quick_start_doi <- "10.1177/00491241211036161"
fixture_doi <- "10.9999/example"

test_that("quick start: search_papers finds registry matches", {
  with_fixture_opts({
    hits <- search_papers("fixture")
    expect_true(is.data.frame(hits))
    expect_true(nrow(hits) >= 1)
    expect_true(any(grepl("Fixture", hits$title, ignore.case = TRUE)))
  })
})

test_that("quick start: load_index returns bibliographic fields", {
  with_fixture_opts({
    idx <- load_index()
    expect_true(is.data.frame(idx))
    expect_true(all(c("doi", "title") %in% names(idx)))
  })
})

test_that("quick start: list_replications returns registered ids", {
  with_fixture_opts({
    reps <- list_replications(fixture_doi)
    expect_true(length(reps) >= 1)
    ids <- vapply(reps, function(x) as.character(x$id), character(1))
    expect_true("fig_1" %in% ids)
    expect_true("tab_1" %in% ids)
  })
})

test_that("quick start: run_replication returns a figure object", {
  with_fixture_opts({
    invisible(suppressMessages(capture.output({
      obj <- run_replication(fixture_doi, "fig_1", format = FALSE)
    })))
    expect_true(
      inherits(obj, "ggplot") ||
        inherits(obj, "gg") ||
        inherits(obj, "data.frame")
    )
  })
})

test_that("quick start: run_replication everything runs all registered replications", {
  with_fixture_opts({
    invisible(capture.output({
      results <- run_replication(fixture_doi, "everything")
    }))
    expect_type(results, "list")
    expect_equal(length(results), 2)
  })
})

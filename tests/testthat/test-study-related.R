test_that("study_upstream_refs_from_meta reads related and extends", {
  meta <- list(
    paper = list(
      related = list(
        list(doi = "https://doi.org/10.1017/S0003055403000534", label = "Original")
      ),
      extends = list(
        repo = "replicate-anything/rep-10.1017-S0003055403000534",
        doi = "10.1017/S0003055403000534"
      )
    )
  )
  refs <- replicateEverything:::study_upstream_refs_from_meta(meta)
  expect_true(length(refs) >= 2L)
  sources <- vapply(refs, function(r) as.character(r$source %||% ""), character(1))
  expect_true("extends" %in% sources)
  expect_true("related" %in% sources)
})

test_that("annotate_index_related builds reverse downstream links", {
  index <- data.frame(
    folder = c("10.1017_s0003055403000534", "rep-10.1017-S0003055403000534--alt-1"),
    handle = c("10.1017_s0003055403000534", "rep-10.1017-S0003055403000534--alt-1"),
    doi = c("10.1017/s0003055403000534", ""),
    title = c("Fearon & Laitin", "Reanalysis"),
    journal = c("APSR", ""),
    year = c(2003L, 2026L),
    authors = c("Fearon, Laitin", "Team"),
    repo = c(
      "replicate-anything/rep-10.1017-S0003055403000534",
      "replicate-anything/rep-10.1017-S0003055403000534--alt-1"
    ),
    collections = c("APSR", "IPI"),
    maintainer_name = c("A", "A"),
    maintainer_email = c("a@example.org", "a@example.org"),
    languages = c("r", "r"),
    article_url = c("", ""),
    stringsAsFactors = FALSE
  )
  metas <- list(
    list(paper = list(doi = "10.1017/S0003055403000534", title = "Fearon & Laitin")),
    list(
      paper = list(
        study_handle = "rep-10.1017-S0003055403000534--alt-1",
        title = "Reanalysis",
        related = list(list(doi = "10.1017/S0003055403000534")),
        extends = list(
          repo = "replicate-anything/rep-10.1017-S0003055403000534",
          doi = "10.1017/S0003055403000534"
        )
      )
    )
  )
  out <- replicateEverything:::annotate_index_related(index, metas = metas)
  expect_true("related_upstream" %in% names(out))
  expect_true("related_downstream" %in% names(out))
  expect_equal(out$related_upstream[[1]], "")
  expect_true(grepl("10\\.1017/s0003055403000534", out$related_upstream[[2]]))
  expect_equal(out$related_downstream[[2]], "")
  expect_equal(out$related_downstream[[1]], "rep-10.1017-S0003055403000534--alt-1")
})

test_that("resolve_related_studies labels upstream and downstream", {
  index <- data.frame(
    folder = "10.1017_s0003055403000534",
    handle = "10.1017_s0003055403000534",
    doi = "10.1017/s0003055403000534",
    title = "Ethnicity, Insurgency, and Civil War",
    journal = "APSR",
    year = 2003L,
    authors = "Fearon, Laitin",
    repo = "replicate-anything/rep-10.1017-S0003055403000534",
    collections = "APSR",
    maintainer_name = "",
    maintainer_email = "",
    languages = "r",
    article_url = "",
    stringsAsFactors = FALSE
  )
  up <- replicateEverything:::resolve_related_studies(
    "10.1017/s0003055403000534",
    direction = "upstream",
    index = index
  )
  expect_equal(length(up), 1L)
  expect_true(isTRUE(up[[1]]$in_registry))
  expect_match(up[[1]]$label, "^Upstream:")
  expect_match(up[[1]]$label, "Ethnicity")
})

test_that("get_study and summary.replicate_study work on fixture", {
  with_fixture_opts({
    st <- get_study(fixture_doi())
    expect_s3_class(st, "replicate_study")
    expect_true(nzchar(st$title) || nzchar(st$doi) || nzchar(st$handle))
    expect_true(is.list(st$step_counts))
    expect_true(is.list(st$related))
    out <- paste(capture.output(summary(st)), collapse = "\n")
    expect_match(out, "Study summary")
    expect_match(out, "Steps:")
  })
})

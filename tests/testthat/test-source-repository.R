test_that("paper_source_repository prefers canonical field over aliases", {
  paper <- list(
    source_repository = "https://reproducibility.worldbank.org/catalog/84",
    source_url = "https://example.org/old",
    source_repo = "https://github.com/old/repo"
  )
  expect_equal(
    paper_source_repository(paper = paper),
    "https://reproducibility.worldbank.org/catalog/84"
  )
})

test_that("paper_source_repository falls back to legacy aliases", {
  expect_equal(
    paper_source_repository(paper = list(source_url = "https://example.org/a")),
    "https://example.org/a"
  )
  expect_equal(
    paper_source_repository(paper = list(source_repo = "https://github.com/org/repo")),
    "https://github.com/org/repo"
  )
  expect_null(paper_source_repository(paper = list(title = "x")))
})

test_that("source_repository_kind classifies common deposit hosts", {
  expect_equal(
    source_repository_kind(
      "https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/OXSQMU"
    ),
    "dataverse"
  )
  expect_equal(
    source_repository_kind("https://osf.io/abcd1/"),
    "osf"
  )
  expect_equal(
    source_repository_kind("https://reproducibility.worldbank.org/catalog/84"),
    "worldbank"
  )
  expect_equal(
    source_repository_kind(
      "https://www.openicpsr.org/openicpsr/project/236844/version/V1/view"
    ),
    "icpsr"
  )
  expect_equal(
    source_repository_kind("https://github.com/wzb-ipi/vaccine_solidarity"),
    "git"
  )
  expect_equal(
    source_repository_kind(
      "https://economics.mit.edu/people/faculty/daron-acemoglu/data-archive"
    ),
    "personal"
  )
  expect_equal(
    source_repository_kind(
      "https://github.com/replicate-anything/replicateEverything"
    ),
    "replicateEverything"
  )
  expect_equal(
    source_repository_kind("replicateEverything"),
    "replicateEverything"
  )
})

test_that("source_repository_href maps bare package credit to GitHub", {
  expect_equal(
    source_repository_href("replicateEverything"),
    "https://github.com/replicate-anything/replicateEverything"
  )
  expect_equal(
    source_repository_href("https://example.org/x"),
    "https://example.org/x"
  )
  expect_null(source_repository_href("not a url"))
})

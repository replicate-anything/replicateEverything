test_that("resolve_replication_language picks sole engine", {
  meta <- list(
    paper = list(doi = "10.5555/test"),
    steps = list(
      list(id = "tab_1", type = "table", label = "T1", engine = "stata")
    )
  )
  expect_equal(resolve_replication_language(meta, "tab_1"), "stata")
})

test_that("resolve_replication_language leaves NULL when multiple engines", {
  meta <- list(
    paper = list(doi = "10.5555/test"),
    steps = list(
      list(id = "tab_1", type = "table", group = "tab_1", code = "code/tab_1.R"),
      list(id = "tab_1_stata", type = "table", group = "tab_1", code = "code/tab_1.do", engine = "stata")
    )
  )
  expect_null(resolve_replication_language(meta, "tab_1"))
})

test_that("resolve_replication_language respects explicit language", {
  meta <- list(
    paper = list(doi = "10.5555/test"),
    steps = list(
      list(id = "tab_1", type = "table", label = "T1", engine = "stata")
    )
  )
  expect_equal(resolve_replication_language(meta, "tab_1", "stata"), "stata")
})

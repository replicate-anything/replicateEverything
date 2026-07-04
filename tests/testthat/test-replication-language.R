dual_engine_meta <- function() {
  list(
    paper = list(
      doi = "https://doi.org/10.1017/S0003055403000534",
      title = "Test paper"
    ),
    replications = list(
      list(
        id = "tab_1",
        group = "tab_1",
        engine = "r",
        type = "table",
        code = "code/tab_1.R"
      ),
      list(
        id = "tab_1_stata",
        group = "tab_1",
        engine = "stata",
        type = "table",
        code = "code/tab_1.do"
      ),
      list(
        id = "fig_1",
        type = "figure",
        code = "code/fig_1.R"
      )
    )
  )
}

test_that("find_replication_entry defaults to R for dual-engine groups", {
  meta <- dual_engine_meta()
  rep <- find_replication_entry(meta, "tab_1")
  expect_equal(rep$id, "tab_1")
  expect_equal(replication_engine(rep), "r")
})

test_that("find_replication_entry selects stata with language", {
  meta <- dual_engine_meta()
  rep <- find_replication_entry(meta, "tab_1", language = "stata")
  expect_equal(rep$id, "tab_1_stata")
})

test_that("find_replication_entry keeps legacy suffixed ids", {
  meta <- dual_engine_meta()
  rep <- find_replication_entry(meta, "tab_1_stata")
  expect_equal(rep$id, "tab_1_stata")
})

test_that("find_replication_entry prefers stata when R missing", {
  meta <- dual_engine_meta()
  meta$replications <- list(meta$replications[[2]], meta$replications[[3]])
  rep <- find_replication_entry(meta, "tab_1")
  expect_equal(rep$id, "tab_1_stata")
})

test_that("replication_logical_id uses group when present", {
  meta <- dual_engine_meta()
  entries <- collect_replication_entries(meta)
  expect_equal(replication_logical_id(entries[[2]]), "tab_1")
  expect_equal(replication_logical_id(entries[[3]]), "fig_1")
})

test_that("normalize_replication_language accepts R and stata", {
  expect_equal(normalize_replication_language("R"), "r")
  expect_equal(normalize_replication_language("stata"), "stata")
  expect_null(normalize_replication_language(NULL))
})

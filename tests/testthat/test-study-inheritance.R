test_that("merge_extended_study_steps pulls inherited analysis_data step", {
  base_meta <- list(
    steps = list(
      list(
        id = "analysis_data",
        type = "transform",
        label = "Prep",
        parents = list(),
        outputs = list("outputs/analysis_data.rds"),
        engine = "r",
        code = "code/steps/analysis_data.R"
      ),
      list(
        id = "tab_1",
        type = "table",
        label = "Table 1",
        parents = list("analysis_data"),
        artifact = "outputs/tab_1.html"
      ),
      list(
        id = "tab_1_stata",
        type = "table",
        label = "Table 1 Stata",
        parents = list(),
        engine = "stata",
        artifact = "outputs/tab_1_stata.html"
      )
    )
  )
  ext_meta <- list(
    paper = list(
      extends = list(
        repo = "replicate-anything/rep-base",
        ref = "main"
      )
    ),
    steps = list(
      list(inherit = "analysis_data"),
      list(
        id = "tab_1",
        type = "table",
        label = "Reanalysis",
        parents = list("analysis_data"),
        code = "code/tab_1.R",
        artifact = "outputs/tab_1.html"
      )
    )
  )

  merged <- merge_extended_study_steps(ext_meta, base_meta, ext_meta$paper$extends)
  ids <- vapply(merged, function(x) x$id, character(1))
  expect_true("analysis_data" %in% ids)
  expect_true("tab_1" %in% ids)
  prep <- merged[[match("analysis_data", ids)]]
  expect_true(isTRUE(prep$.inherited))
  tab <- merged[[match("tab_1", ids)]]
  expect_equal(tab$label, "Reanalysis")
  expect_false("tab_1_stata" %in% ids)
})

test_that("resolve_study_file reads base outputs for extension studies", {
  base_dir <- file.path(tempdir(), paste0("base-study-", sample.int(1e6, 1)))
  ext_dir <- file.path(tempdir(), paste0("ext-study-", sample.int(1e6, 1)))
  on.exit({
    unlink(base_dir, recursive = TRUE)
    unlink(ext_dir, recursive = TRUE)
  }, add = TRUE)
  dir.create(file.path(base_dir, "outputs"), recursive = TRUE)
  writeLines("x", file.path(base_dir, "outputs/analysis_data.rds"))
  dir.create(ext_dir, recursive = TRUE)

  meta <- list(
    .extends_context = list(local_root = base_dir)
  )
  ctx <- list(local_root = ext_dir)
  hit <- resolve_study_file("outputs/analysis_data.rds", ctx, meta = meta, local_only = TRUE)
  expect_true(file.exists(hit))
  expect_equal(
    normalizePath(hit, winslash = "/"),
    normalizePath(file.path(base_dir, "outputs/analysis_data.rds"), winslash = "/")
  )
})

test_that("inherit entry can override format child code path", {
  base_meta <- list(
    steps = list(
      list(
        id = "tab_1",
        type = "table",
        label = "Table 1",
        parents = list("analysis_data"),
        format = "format_tab_1",
        code = "code/tab_1.R"
      ),
      list(
        id = "tab_1_format",
        type = "format",
        label = "Table 1 format",
        parent = "tab_1",
        code = "code/tab_1.R"
      )
    )
  )
  ext_meta <- list(
    paper = list(extends = list(repo = "replicate-anything/rep-base", ref = "main")),
    steps = list(
      list(inherit = "tab_1_format", code = "code/format_ext.R")
    )
  )
  merged <- merge_extended_study_steps(ext_meta, base_meta, ext_meta$paper$extends)
  fmt <- merged[[which(vapply(merged, function(x) x$id == "tab_1_format", logical(1)))]]
  expect_true(isTRUE(fmt$.inherited))
  expect_equal(fmt$code, "code/format_ext.R")
})

test_that("study_everything_step_ids excludes format children", {
  meta <- list(
    steps = list(
      list(id = "analysis_data", type = "transform", parents = list()),
      list(id = "tab_1", type = "table", parents = list("analysis_data")),
      list(id = "tab_1_format", type = "format", parent = "tab_1")
    )
  )
  ids <- study_everything_step_ids(meta)
  expect_equal(ids, c("analysis_data", "tab_1"))
  expect_false("tab_1_format" %in% ids)
})

test_that("step_run_context routes inherited steps to base local_root", {
  meta <- list(
    .extends_context = list(
      local_root = "/base/path",
      base_url = "https://example.com/base/"
    )
  )
  step <- list(id = "analysis_data", .inherited = TRUE)
  ctx <- list(local_root = "/ext/path", base_url = "https://example.com/ext/")
  run_ctx <- step_run_context(step, meta, ctx)
  expect_equal(run_ctx$local_root, "/base/path")
  expect_equal(run_ctx$base_url, "https://example.com/base/")
})

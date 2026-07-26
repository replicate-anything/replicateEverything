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
        outputs = list("outputs/tab_1.html")
      ),
      list(
        id = "tab_1_stata",
        type = "table",
        label = "Table 1 Stata",
        parents = list(),
        engine = "stata",
        outputs = list("outputs/tab_1_stata.html")
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
        outputs = list("outputs/tab_1.html")
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
  base_dir <- file.path(tempdir(), paste0("base-run-", sample.int(1e6, 1)))
  on.exit(unlink(base_dir, recursive = TRUE), add = TRUE)
  dir.create(base_dir, recursive = TRUE)
  meta <- list(
    .extends_context = list(
      local_root = base_dir,
      base_url = "https://example.com/base/",
      materials_repo = "replicate-anything/rep-base",
      ref = "main"
    )
  )
  step <- list(id = "analysis_data", .inherited = TRUE)
  ctx <- list(local_root = "/ext/path", base_url = "https://example.com/ext/")
  run_ctx <- step_run_context(step, meta, ctx)
  expect_equal(run_ctx$local_root, base_dir)
  expect_equal(run_ctx$base_url, "https://example.com/base/")
  expect_equal(run_ctx$materials_repo, "replicate-anything/rep-base")
})

test_that("step_run_context cold host still pins parent base_url and materials_repo", {
  meta <- list(
    repo = "replicate-anything/rep-extension",
    .extends_context = list(
      repo = "replicate-anything/rep-base",
      local_root = NULL,
      base_url = "https://raw.githubusercontent.com/replicate-anything/rep-base/main/",
      materials_repo = "replicate-anything/rep-base",
      ref = "main"
    )
  )
  step <- list(id = "analysis_data", .inherited = TRUE, code = "code/steps/analysis_data.R")
  ctx <- list(
    local_root = "/ext/path",
    base_url = "https://raw.githubusercontent.com/replicate-anything/rep-extension/main/",
    materials_repo = "replicate-anything/rep-extension",
    is_folder_study = TRUE
  )
  run_ctx <- step_run_context(step, meta, ctx)
  expect_null(run_ctx$local_root)
  expect_equal(
    run_ctx$base_url,
    "https://raw.githubusercontent.com/replicate-anything/rep-base/main/"
  )
  expect_equal(run_ctx$materials_repo, "replicate-anything/rep-base")
  expect_equal(run_ctx$materials_ref, "main")

  code_ctx <- step_code_context(step, meta, ctx)
  expect_equal(
    registry_url(code_ctx$base_url, step$code),
    "https://raw.githubusercontent.com/replicate-anything/rep-base/main/code/steps/analysis_data.R"
  )
  expect_false(grepl("--alt-1|rep-extension", registry_url(code_ctx$base_url, step$code)))
})

test_that("materials_repo_override narrows folder candidates to parent only", {
  meta <- list(
    repo = "replicate-anything/rep-10.1017-S0003055403000534--alt-1",
    paper = list(study_handle = "rep-10.1017-S0003055403000534--alt-1")
  )
  ctx <- list(materials_repo = "replicate-anything/rep-10.1017-S0003055403000534")
  expect_true(materials_repo_override(meta, ctx))
  cands <- study_folder_candidates(meta, ctx)
  expect_equal(cands, "rep-10.1017-S0003055403000534")
  expect_false(any(grepl("--alt-1", cands)))
})

test_that("registry_url avoids double slashes when base ends with /", {
  expect_equal(
    registry_url("https://raw.githubusercontent.com/org/repo/main/", "code/steps/a.R"),
    "https://raw.githubusercontent.com/org/repo/main/code/steps/a.R"
  )
  expect_equal(
    registry_url("https://raw.githubusercontent.com/org/repo/main", "/code/steps/a.R"),
    "https://raw.githubusercontent.com/org/repo/main/code/steps/a.R"
  )
})

test_that("study_repo_slug prefers materials_repo from inherited run context", {
  meta <- list(repo = "replicate-anything/rep-extension")
  ctx <- list(materials_repo = "replicate-anything/rep-base")
  expect_equal(study_repo_slug(meta, ctx), "replicate-anything/rep-base")
  expect_equal(
    study_repo_slug(meta, list(materials_repo = DEFAULT_REGISTRY_REPO)),
    "replicate-anything/rep-extension"
  )
})

test_that("study_repo_ref prefers materials_ref from inherited run context", {
  meta <- list(paper = list(study_ref = "extension-branch"))
  expect_equal(study_repo_ref(meta), "extension-branch")
  expect_equal(
    study_repo_ref(meta, list(materials_ref = "parent-branch")),
    "parent-branch"
  )
})

test_that("step_code_context keeps extension-local overrides on inherited format steps", {
  ext_dir <- file.path(tempdir(), paste0("ext-override-", sample.int(1e6, 1)))
  on.exit(unlink(ext_dir, recursive = TRUE), add = TRUE)
  dir.create(file.path(ext_dir, "code"), recursive = TRUE)
  writeLines("format_tab_1 <- function(x) x", file.path(ext_dir, "code/tab_1.R"))

  meta <- list(
    .extends_context = list(
      local_root = "/base/path",
      base_url = "https://example.com/base/",
      materials_repo = "replicate-anything/rep-base"
    )
  )
  step <- list(
    id = "tab_1_format",
    code = "code/tab_1.R",
    .inherited = TRUE
  )
  ctx <- list(
    local_root = ext_dir,
    base_url = "https://example.com/ext/",
    materials_repo = "replicate-anything/rep-extension"
  )
  code_ctx <- step_code_context(step, meta, ctx)
  expect_equal(code_ctx$local_root, ext_dir)
  expect_equal(code_ctx$base_url, "https://example.com/ext/")
})

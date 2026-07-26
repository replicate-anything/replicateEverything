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

test_that("artifact_lookup_candidates for inherited prep uses parent paths", {
  base_dir <- file.path(tempdir(), paste0("base-disp-", sample.int(1e6, 1)))
  ext_dir <- file.path(tempdir(), paste0("ext-disp-", sample.int(1e6, 1)))
  on.exit({
    unlink(base_dir, recursive = TRUE)
    unlink(ext_dir, recursive = TRUE)
  }, add = TRUE)
  dir.create(file.path(base_dir, "outputs"), recursive = TRUE)
  dir.create(file.path(ext_dir, "outputs"), recursive = TRUE)
  df <- data.frame(x = 1:3, y = letters[1:3])
  saveRDS(df, file.path(base_dir, "outputs/analysis_data.rds"))
  # Child owns its table claim only.
  writeLines("<table><tr><td>1</td></tr></table>", file.path(ext_dir, "outputs/tab_1.html"))

  writeLines(paste(
    "paper:",
    "  title: Extension",
    "  extends:",
    "    repo: replicate-anything/rep-base-disp",
    "    ref: main",
    "steps:",
    "  - inherit: analysis_data",
    "  - id: tab_1",
    "    type: table",
    "    label: Table 1",
    "    parents: [analysis_data]",
    "    outputs: [outputs/tab_1.html]",
    sep = "\n"
  ), file.path(ext_dir, "replication.yml"))

  writeLines(paste(
    "paper:",
    "  title: Base",
    "steps:",
    "  - id: analysis_data",
    "    type: transform",
    "    label: Prep",
    "    outputs: [outputs/analysis_data.rds]",
    "    code: code/steps/analysis_data.R",
    "  - id: tab_1",
    "    type: table",
    "    outputs: [outputs/tab_1.html]",
    sep = "\n"
  ), file.path(base_dir, "replication.yml"))

  # Point extends.repo folder resolution at our temp base via study_folders_root
  # sibling layout: both folders under the same parent.
  monorepo <- dirname(base_dir)
  # Use predictable folder names under a shared root.
  base_name <- "rep-base-disp"
  ext_name <- "rep-ext-disp"
  base_link <- file.path(monorepo, base_name)
  ext_link <- file.path(monorepo, ext_name)
  if (dir.exists(base_link)) unlink(base_link, recursive = TRUE)
  if (dir.exists(ext_link)) unlink(ext_link, recursive = TRUE)
  # Copy rather than symlink for Windows portability.
  dir.create(base_link, recursive = TRUE)
  dir.create(ext_link, recursive = TRUE)
  file.copy(list.files(base_dir, full.names = TRUE), base_link, recursive = TRUE)
  file.copy(list.files(ext_dir, full.names = TRUE), ext_link, recursive = TRUE)
  on.exit({
    unlink(base_link, recursive = TRUE)
    unlink(ext_link, recursive = TRUE)
  }, add = TRUE)

  writeLines(paste(
    "paper:",
    "  title: Extension",
    "  extends:",
    "    repo: replicate-anything/rep-base-disp",
    "    ref: main",
    "steps:",
    "  - inherit: analysis_data",
    "  - id: tab_1",
    "    type: table",
    "    label: Table 1",
    "    parents: [analysis_data]",
    "    outputs: [outputs/tab_1.html]",
    sep = "\n"
  ), file.path(ext_link, "replication.yml"))

  withr::local_options(list(
    replicateEverything.study_folders_root = monorepo,
    replicateEverything.use_sibling_packages = TRUE
  ))

  # Build merged meta the same way the package does for folder studies.
  meta <- yaml::read_yaml(file.path(ext_link, "replication.yml"))
  meta$.local_root <- normalizePath(ext_link, winslash = "/", mustWork = FALSE)
  meta <- merge_extended_study_meta(meta)
  ctx <- list(
    local_root = meta$.local_root,
    base_url = "https://raw.githubusercontent.com/replicate-anything/rep-ext-disp/main/",
    materials_repo = "replicate-anything/rep-ext-disp",
    is_folder_study = TRUE
  )

  prep <- find_replication_entry(meta, "analysis_data")
  expect_true(is_inherited_step(prep))
  run_ctx <- step_run_context(prep, meta, ctx)
  expect_true(grepl("rep-base-disp", run_ctx$local_root %||% ""))
  expect_true(grepl("rep-base-disp", run_ctx$base_url %||% ""))

  # Direct candidate construction mirrors artifact_lookup_candidates routing.
  cands <- character(0)
  for (rel in study_artifact_rel_candidates(prep)) {
    local <- file.path(run_ctx$local_root, rel)
    if (file.exists(local)) {
      cands <- c(cands, normalizePath(local, winslash = "/", mustWork = FALSE))
    }
    cands <- c(cands, registry_url(run_ctx$base_url, rel))
  }
  expect_true(any(grepl("rep-base-disp", cands)))
  expect_false(any(grepl("rep-ext-disp.*analysis_data\\.rds$", cands)))
  expect_true(any(file.exists(cands[!grepl("^https?://", cands)])))

  # Display enablement for inherited prep when parent sink exists.
  expect_true(file.exists(file.path(run_ctx$local_root, "outputs/analysis_data.rds")))

  # check_display_sink_rows: inherited prep must not fail against child root.
  sinks <- check_display_sink_rows(meta, meta$.local_root)
  row <- sinks[sinks$check == "display_sink_analysis_data", , drop = FALSE]
  expect_equal(nrow(row), 1L)
  expect_true(isTRUE(row$passed[[1]]))
  expect_true(grepl("inherited|parent", row$message[[1]], ignore.case = TRUE))
})

test_that("alt-1 inherited analysis_data Display enablement uses parent", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  ext_dir <- file.path(monorepo_root, "rep-10.1017-S0003055403000534--alt-1")
  base_dir <- file.path(monorepo_root, "rep-10.1017-S0003055403000534")
  testthat::skip_if_not(dir.exists(ext_dir), "alt-1 study repo missing")
  testthat::skip_if_not(dir.exists(base_dir), "Fearon study repo missing")
  testthat::skip_if_not(
    file.exists(file.path(base_dir, "outputs", "analysis_data.rds")),
    "parent analysis_data.rds missing"
  )
  testthat::skip_if_not(
    file.exists(file.path(ext_dir, "outputs", "tab_1.html")),
    "alt-1 tab_1.html missing"
  )

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  doi <- "rep-10.1017-S0003055403000534--alt-1"
  expect_true(step_display_output_exists(doi, "analysis_data"))
  expect_true(step_display_output_exists(doi, "tab_1"))

  cands <- artifact_lookup_candidates(doi, "analysis_data")
  expect_true(length(cands) > 0L)
  expect_true(any(grepl("S0003055403000534(?!--alt-1)", cands, perl = TRUE)))
  expect_false(any(grepl("--alt-1.*/outputs/analysis_data\\.rds", cands)))

  path <- get_artifact_path(doi, "analysis_data")
  expect_true(!is.null(path))
  expect_true(grepl("S0003055403000534", path))
  expect_false(grepl("--alt-1", path))

  tab_path <- get_artifact_path(doi, "tab_1")
  expect_true(!is.null(tab_path))
  expect_true(grepl("--alt-1", tab_path))

  loaded <- load_artifact(doi, "analysis_data")
  expect_s3_class(loaded, "data.frame")

  meta <- get_replication_meta(doi)
  sinks <- check_display_sink_rows(meta, normalizePath(ext_dir, winslash = "/"))
  row <- sinks[sinks$check == "display_sink_analysis_data", , drop = FALSE]
  expect_equal(nrow(row), 1L)
  expect_true(isTRUE(row$passed[[1]]))
  expect_true(grepl("inherited|parent", row$message[[1]], ignore.case = TRUE))
})

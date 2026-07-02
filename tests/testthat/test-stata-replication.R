test_that("auto_detect_monorepo_root finds sibling registry", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  testthat::skip_if_not(
    file.exists(file.path(monorepo_root, "registry", "index.csv")),
    "monorepo registry missing"
  )
  detected <- auto_detect_monorepo_root()
  testthat::expect_equal(detected, monorepo_root)
})

test_that("get_replication_meta finds local Stata study without options", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1596-1813-9450-10626")
  testthat::skip_if_not(dir.exists(study_dir), "Stata study repo missing")

  withr::local_options(list(
    replicateEverything.registry_root = NULL,
    replicateEverything.index = NULL,
    replicateEverything.use_sibling_packages = NULL,
    replicateEverything.study_folders_root = NULL
  ))

  meta <- get_replication_meta("10.1596/1813-9450-10626")
  reps <- meta$replications %||% list()
  testthat::expect_true(length(reps) > 0L)
  tab1 <- reps[vapply(reps, function(x) identical(x$id, "tab_1"), logical(1))]
  testthat::expect_length(tab1, 1L)
  testthat::expect_equal(tab1[[1]]$engine[[1]], "stata")
})

test_that("replication_engine detects Stata entries", {
  rep <- list(
    id = "tab_1",
    engine = "stata",
    code = "code/tab_1.do"
  )
  expect_equal(replication_engine(rep), "stata")
  expect_true(is_stata_replication(rep))

  r_rep <- list(id = "fig_1", code = "code/fig_1.R")
  expect_equal(replication_engine(r_rep), "r")
  expect_false(is_stata_replication(r_rep))

  do_rep <- list(id = "tab_1", code = "code/tab_1.do")
  expect_equal(replication_engine(do_rep), "stata")
})

test_that("get_code includes stata_source for Stata studies", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1596-1813-9450-10626")
  testthat::skip_if_not(dir.exists(study_dir), "Stata study repo missing")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  code <- get_code("10.1596/1813-9450-10626", "tab_1")
  testthat::expect_true(any(grepl("esttab", code, fixed = TRUE)))
  testthat::expect_true(any(grepl("stata/Table1.do", code, fixed = TRUE)))
})

test_that("study_folder_map_keys includes registry and repo aliases", {
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1596/1813-9450-10626",
      study_folder = "rep-10.1596-1813-9450-10626"
    ),
    repo = "replicate-anything/rep-10.1596-1813-9450-10626"
  )
  ctx <- list(
    doi = "10.1596/1813-9450-10626",
    folder = "10.1596_1813-9450-10626"
  )
  keys <- study_folder_map_keys(meta, ctx)
  expect_true("10.1596_1813-9450-10626" %in% keys)
  expect_true("rep-10.1596-1813-9450-10626" %in% keys)
})

test_that("lookup_study_folders_option matches rep-* alias", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1596-1813-9450-10626")
  testthat::skip_if_not(dir.exists(study_dir), "Stata study repo missing")

  meta <- get_replication_meta("10.1596/1813-9450-10626")
  ctx <- paper_context("10.1596/1813-9450-10626")

  withr::local_options(list(
    replicateEverything.study_folders = list(
      "rep-10.1596-1813-9450-10626" = study_dir
    ),
    replicateEverything.use_sibling_packages = FALSE,
    replicateEverything.study_folders_root = NULL
  ))

  resolved <- lookup_study_folders_option(meta, ctx)
  expect_equal(
    normalizePath(resolved, winslash = "/", mustWork = FALSE),
    normalizePath(study_dir, winslash = "/", mustWork = FALSE)
  )
})

test_that("stata_result_path accepts list and character paths", {
  smcl <- tempfile(fileext = ".smcl")
  writeLines("test", smcl)
  on.exit(unlink(smcl), add = TRUE)

  expect_equal(
    stata_result_path(list(output_path = smcl)),
    smcl
  )
  expect_equal(stata_result_path(smcl), smcl)

  normalized <- normalize_stata_result_object(smcl)
  expect_true(inherits(normalized, "stata_replication_result"))
  expect_equal(normalized$output_path, smcl)
})

test_that("materialize_folder_study_from_github caches public study repo", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()

  cache_root <- tempfile("study-cache-")
  on.exit(unlink(cache_root, recursive = TRUE), add = TRUE)
  withr::local_options(list(replicateEverything.study_cache_root = cache_root))

  path <- materialize_folder_study_from_github(
    "replicate-anything/rep-10.1596-1813-9450-10626",
    "main"
  )
  expect_true(dir.exists(path))
  expect_true(file.exists(file.path(path, "replication.yml")))
  expect_equal(
    materialize_folder_study_from_github(
      "replicate-anything/rep-10.1596-1813-9450-10626",
      "main"
    ),
    path
  )
})

test_that("replication_code_language_for reads study metadata", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1596-1813-9450-10626")
  testthat::skip_if_not(dir.exists(study_dir), "Stata study repo missing")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  expect_equal(
    replication_code_language_for("10.1596/1813-9450-10626", "tab_1"),
    "stata"
  )
})

test_that("get_replication_meta merges stata_packages for folder-backed stub", {
  with_fixture_stata_opts({
    meta <- get_replication_meta(fixture_stata_doi())
    expect_equal(
      as.character(meta$stata_packages),
      "estout"
    )
    expect_equal(meta$languages[[1]], "stata")
    expect_true(length(meta$steps %||% list()) > 0L)
  })
})

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

test_that("get_replication_meta finds local Stata study from fixture registry", {
  with_fixture_stata_opts({
    meta <- get_replication_meta(fixture_stata_doi())
    reps <- folder_display_replications(meta)
    expect_true(length(reps) > 0L)
    tab1 <- reps[vapply(reps, function(x) identical(x$id, "tab_1"), logical(1))]
    expect_length(tab1, 1L)
    expect_equal(tab1[[1]]$engine[[1]], "stata")
  })
})

test_that("stata_deps_install_targets generates install from stata_packages", {
  study <- fixture_stata_study_root()
  meta <- fixture_stata_meta()
  targets <- replicateEverything:::stata_deps_install_targets(study, meta = meta)
  expect_true(targets$generated)
  expect_equal(targets$packages, "estout")
  expect_true(file.exists(targets$scripts[[1]]))
  lines <- readLines(targets$scripts[[1]], warn = FALSE)
  expect_true(any(grepl("ssc install estout", lines)))
})

test_that("stata_deps_probe_lines_from_packages checks commands and reghdfe stack", {
  lines <- replicateEverything:::stata_deps_probe_lines_from_packages(c("ivreg2", "estout"))
  expect_true(any(grepl("which ivreg2", lines)))
  expect_true(any(grepl("which eststo", lines)))
  reghdfe_lines <- replicateEverything:::stata_deps_probe_lines_from_packages(
    c("ftools", "reghdfe", "estout")
  )
  expect_true(any(grepl("which require", reghdfe_lines)))
  expect_true(any(grepl("noi reghdfe", reghdfe_lines)))
})

test_that("install_stata_dependencies probes only when install_stata_deps is FALSE", {
  study <- tempfile("study-")
  dir.create(study, recursive = TRUE)
  on.exit(unlink(study, recursive = TRUE), add = TRUE)
  withr::local_options(list(replicateEverything.install_stata_deps = FALSE))
  expect_silent(
    replicateEverything:::install_stata_dependencies(
      study,
      install_deps = TRUE
    )
  )
})

test_that("stata_dependencies_satisfied returns NA without probe config", {
  expect_true(is.na(
    replicateEverything:::stata_dependencies_satisfied(tempdir(), meta = list())
  ))
})

test_that("stata_dependencies_satisfied returns TRUE when generated probe passes", {
  skip_if(is.null(replicateEverything:::find_stata_executable()), "Stata not installed")
  study <- fixture_stata_study_root()
  meta <- fixture_stata_meta()
  probe_ok <- replicateEverything:::stata_dependencies_satisfied(
    study,
    timeout = 180L,
    meta = meta
  )
  if (!isTRUE(probe_ok)) {
    skip("estout/eststo not installed in Stata (expected on maintainer machines)")
  }
  expect_true(probe_ok)
})

test_that("stata_log_suggests_missing_dependency detects SSC install prompts", {
  text <- "install it:\n - install from SSC\nr(9);"
  expect_true(replicateEverything:::stata_log_suggests_missing_dependency(text))
})

test_that("stata_dependency_hint points to study replication.yml not hardcoded SSC", {
  study <- fixture_stata_study_root()
  meta <- fixture_stata_meta()
  text <- "unrecognized command: foo\nr(199);"
  hint <- replicateEverything:::stata_dependency_hint(
    text,
    study_root = study,
    meta = meta
  )
  expect_true(grepl("replication.yml", hint))
  expect_true(grepl("stata_packages", hint))
  expect_false(grepl("ssc install reghdfe", hint))
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

test_that("get_code includes stata_source for Stata fixture study", {
  with_fixture_stata_opts({
    code <- get_code(fixture_stata_doi(), "tab_1")
    expect_true(any(grepl("esttab", code, fixed = TRUE)))
    expect_true(any(grepl("ANALYSIS", code, fixed = TRUE)))
  })
})

test_that("get_code includes stata_source for monorepo Stata study (integration)", {
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
  testthat::expect_true(any(grepl("ANALYSIS", code, fixed = TRUE)))
  testthat::expect_true(any(grepl("summ", code, fixed = TRUE) | grepl("esttab", code, fixed = TRUE)))
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

test_that("lookup_study_folders_option matches rep-* alias for fixture study", {
  study_dir <- fixture_stata_study_root()
  meta <- fixture_stata_meta()
  ctx <- paper_context(fixture_stata_doi())

  withr::local_options(list(
    replicateEverything.study_folders = list(
      "rep-10.9999-stata" = study_dir
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

test_that("replication_code_language_for reads fixture study metadata", {
  with_fixture_stata_opts({
    expect_equal(
      replication_code_language_for(fixture_stata_doi(), "tab_1"),
      "stata"
    )
  })
})

study_root <- normalizePath(
  file.path(testthat::test_path(".."), "..", "..", "rep-10.1017-s0003055422000284"),
  winslash = "/",
  mustWork = FALSE
)

test_that("extract_stata_file_calls finds quoted and macro paths", {
  lines <- c(
    'do "code/helpers/init_study_paths.do"',
    'do "${maindir}/code/tables/mk_tab_1.do"',
    "quietly do \"code/helpers/setup_analysis.do\"",
    "capture do \"missing.do\""
  )
  calls <- extract_stata_file_calls(lines)
  expect_equal(nrow(calls), 4L)
  expect_true(any(grepl("init_study_paths", calls$path)))
  expect_true(any(grepl("mk_tab_1", calls$path)))
})

test_that("extract_stata_file_calls ignores comments", {
  lines <- c(
    '* do "ignored.do"',
    "// do \"ignored.do\"",
    "do \"real.do\""
  )
  calls <- extract_stata_file_calls(lines)
  expect_equal(nrow(calls), 1L)
  expect_equal(calls$path[[1]], "real.do")
})

test_that("resolve_stata_path substitutes maindir", {
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  globals <- default_stata_globals(study_root)
  resolved <- resolve_stata_path(
    "${maindir}/code/tables/mk_tab_1.do",
    study_root,
    globals = globals
  )
  expect_equal(resolved$status, "ok")
  expect_true(file.exists(resolved$resolved))
  expect_equal(resolved$display, "code/tables/mk_tab_1.do")
})

test_that("normalize_stata_globals restores defaults for empty or unnamed globals", {
  study_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "rep-10.1017-s0003055422000284"),
    winslash = "/",
    mustWork = FALSE
  )
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  defaults <- default_stata_globals(study_root)
  expect_equal(normalize_stata_globals(study_root, character()), defaults)
  expect_equal(normalize_stata_globals(study_root, NULL), defaults)
  expect_equal(
    normalize_stata_globals(study_root, c("/some/path")),
    defaults
  )
  merged <- normalize_stata_globals(
    study_root,
    list(maindir = defaults[["maindir"]], result = "C:/tmp/staging")
  )
  expect_equal(merged[["maindir"]], defaults[["maindir"]])
  expect_equal(merged[["result"]], "C:/tmp/staging")
})

test_that("render_code_html_with_links resolves Blair paths with empty globals", {
  study_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "rep-10.1017-s0003055422000284"),
    winslash = "/",
    mustWork = FALSE
  )
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  lines <- readLines(file.path(study_root, "code/tables/tab_1.do"), warn = FALSE)
  rendered <- render_code_html_with_links(
    lines,
    language = "stata",
    study_root = study_root,
    source_path = "code/tables/tab_1.do",
    globals = character()
  )
  statuses <- vapply(rendered$links, function(x) x$status, character(1))
  expect_true(all(statuses == "ok"))
})

test_that("resolve_stata_path resolves study-root relative paths", {
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  globals <- default_stata_globals(study_root)
  resolved <- resolve_stata_path(
    "code/helpers/init_study_paths.do",
    study_root,
    globals = globals,
    from_file = file.path(study_root, "code/tables/tab_1.do")
  )
  expect_equal(resolved$status, "ok")
  expect_true(file.exists(resolved$resolved))
  expect_equal(resolved$display, "code/helpers/init_study_paths.do")
})

test_that("resolve_stata_path reports missing files", {
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  globals <- default_stata_globals(study_root)
  resolved <- resolve_stata_path(
    "${maindir}/code/tables/not_here.do",
    study_root,
    globals = globals
  )
  expect_equal(resolved$status, "missing")
})

test_that("resolve_stata_path blocks paths outside study root", {
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  globals <- default_stata_globals(study_root)
  resolved <- resolve_stata_path(
    "../../../etc/passwd",
    study_root,
    globals = globals,
    from_file = file.path(study_root, "code/tables/tab_1.do")
  )
  expect_equal(resolved$status, "outside_root")
})

test_that("build_code_file_graph walks Blair tab_1 runner", {
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  graph <- build_code_file_graph(
    "code/tables/tab_1.do",
    study_root,
    language = "stata"
  )
  expect_true("code/tables/tab_1.do" %in% names(graph$nodes))
  expect_true("code/tables/mk_tab_1.do" %in% unlist(graph$edges))
  expect_true("code/helpers/init_study_paths.do" %in% unlist(graph$edges))
})

test_that("extract_r_source_calls finds source paths", {
  lines <- c('source("code/helpers/format_table.R")', '# source("skip.R")')
  calls <- extract_r_source_calls(lines)
  expect_equal(nrow(calls), 1L)
  expect_equal(calls$path[[1]], "code/helpers/format_table.R")
})

test_that("get_code style source returns raw runner for Blair", {
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))
  code <- get_code("10.1017/S0003055422000284", "tab_1", language = "stata", style = "source")
  text <- paste(code, collapse = "\n")
  expect_true(grepl('do "${maindir}/code/tables/mk_tab_1.do"', text, fixed = TRUE))
  expect_false(grepl("ANALYSIS", text, fixed = TRUE))
})

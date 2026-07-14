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

test_that("normalize_stata_globals clamps maindir outside study root", {
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  defaults <- default_stata_globals(study_root)
  cache_root <- file.path(tempdir(), "outside-maindir-test")
  bad <- defaults
  bad[["maindir"]] <- cache_root
  bad[["rawdir"]] <- file.path(cache_root, "data/raw")
  clamped <- normalize_stata_globals(study_root, bad)
  expect_equal(clamped[["maindir"]], defaults[["maindir"]])
  expect_equal(clamped[["rawdir"]], defaults[["rawdir"]])
  resolved <- resolve_stata_path(
    "${maindir}/code/tables/mk_tab_1.do",
    study_root,
    globals = bad
  )
  expect_equal(resolved$status, "ok")
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

test_that("failed code links include diagnostic markers", {
  testthat::skip_if_not(dir.exists(study_root), "Blair study repo missing")
  lines <- c('do "${maindir}/code/tables/not_here.do"')
  rendered <- render_code_html_with_links(
    lines,
    language = "stata",
    study_root = study_root,
    source_path = "code/tables/tab_1.do",
    globals = default_stata_globals(study_root)
  )
  expect_true(grepl("code-file-link--missing", rendered$html, fixed = TRUE))
  expect_true(grepl("code-link-diagnostic", rendered$html, fixed = TRUE))
  expect_true(nzchar(rendered$links[[1]]$diagnostics$study_root))
  title <- format_code_link_diagnostic_title(rendered$links[[1]]$diagnostics)
  expect_match(title, "File not found")
  expect_match(title, "study_root:")
  expect_match(title, "maindir:")
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

test_that("extract_r_source_calls finds sys.source paths", {
  lines <- c('sys.source("code/helpers/init.R")', 'source("../helpers/util.R")')
  calls <- extract_r_source_calls(lines)
  expect_equal(nrow(calls), 2L)
  expect_equal(calls$command, c("sys.source", "source"))
  expect_equal(calls$path[[1]], "code/helpers/init.R")
  expect_equal(calls$path[[2]], "../helpers/util.R")
})

code_links_fixture_root <- function(valid = TRUE) {
  tmp <- file.path(tempdir(), paste0("code-links-fixture-", if (valid) "ok" else "bad"))
  unlink(tmp, recursive = TRUE)
  dir.create(file.path(tmp, "code", "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(tmp, "code", "helpers"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(tmp, "outputs"), recursive = TRUE, showWarnings = FALSE)

  helper_path <- file.path(tmp, "code", "helpers", "shared.R")
  writeLines("shared_flag <- TRUE", helper_path)
  if (!valid) {
    unlink(helper_path)
  }

  writeLines(
    c(
      'source("../helpers/shared.R")',
      "make_tab_1 <- function(data) data"
    ),
    file.path(tmp, "code", "tables", "tab_1.R")
  )

  meta <- list(
    paper = list(
      doi = "https://doi.org/10.9999/code-links",
      title = "Code links fixture",
      study_repo = "replicate-anything/rep-code-links"
    ),
    steps = list(
      list(
        id = "tab_1",
        type = "table",
        code = "code/tables/tab_1.R",
        outputs = list("outputs/tab_1.html")
      )
    )
  )
  yaml::write_yaml(meta, file.path(tmp, "replication.yml"))
  normalizePath(tmp, winslash = "/", mustWork = FALSE)
}

test_that("resolve_code_path resolves caller-relative R paths in generic fixture", {
  root <- code_links_fixture_root(valid = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  resolved <- resolve_code_path(
    "../helpers/shared.R",
    study_root = root,
    from_file = file.path(root, "code/tables/tab_1.R")
  )
  expect_equal(resolved$status, "ok")
  expect_equal(resolved$display, "code/helpers/shared.R")
})

test_that("collect_code_link_issues passes on valid generic fixture", {
  root <- code_links_fixture_root(valid = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  meta <- yaml::read_yaml(file.path(root, "replication.yml"))
  issues <- collect_code_link_issues(root, meta)
  expect_equal(nrow(issues), 0L)
})

test_that("collect_code_link_issues fails on broken link in generic fixture", {
  root <- code_links_fixture_root(valid = FALSE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  meta <- yaml::read_yaml(file.path(root, "replication.yml"))
  issues <- collect_code_link_issues(root, meta)
  expect_equal(nrow(issues), 1L)
  expect_match(issues$message[[1]], "In code/tables/tab_1.R line 1")
  expect_match(issues$message[[1]], "source\\('../helpers/shared.R'\\)")
  expect_match(issues$message[[1]], "expected code/helpers/shared.R")
})

test_that("check_code_links returns checklist rows for broken fixture", {
  root <- code_links_fixture_root(valid = FALSE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  meta <- yaml::read_yaml(file.path(root, "replication.yml"))
  rows <- check_code_links(root, meta)
  expect_false(all(rows$passed))
  expect_true("code_links" %in% rows$check)
  code_links_row <- rows[rows$check == "code_links", , drop = FALSE]
  expect_false(code_links_row$passed[[1]])
})

test_that("check_replication includes code_links check for broken fixture", {
  root <- code_links_fixture_root(valid = FALSE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  result <- check_replication(root, full_replication = FALSE)
  expect_false(result$ok)
  expect_true("code_links" %in% result$checks$check)
  link_rows <- result$checks[grepl("^code_link", result$checks$check), , drop = FALSE]
  expect_gt(nrow(link_rows), 0L)
  expect_false(all(link_rows$passed))
})

test_that("resolve_code_path resolves R parent-relative source paths from caller", {
  velez_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "rep-10.1017-s0003055426101622"),
    winslash = "/",
    mustWork = FALSE
  )
  testthat::skip_if_not(dir.exists(velez_root), "Velez study repo missing")
  resolved <- resolve_code_path(
    "../helpers/dataverse_deposit.R",
    study_root = velez_root,
    from_file = file.path(velez_root, "code/tables/tab_1.R")
  )
  expect_equal(resolved$status, "ok")
  expect_true(file.exists(resolved$resolved))
  expect_equal(resolved$display, "code/helpers/dataverse_deposit.R")
})

test_that("parse_stata_globals ignores runtime macro/local assignments", {
  lines <- c(
    'global maindir "`root\'"',
    'global rawdir "${maindir}/data/raw"',
    'global result "${REPLICATE_STATA_RESULT}"',
    'global literal "C:/study/data"'
  )
  parsed <- parse_stata_globals(lines, character())
  expect_equal(parsed, c(literal = "C:/study/data"))
})

test_that("prepare_code_viewer_state links Blair tab_1 do files", {
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
  viewer <- prepare_code_viewer_state(
    "10.1017/S0003055422000284",
    "tab_1",
    language = "stata"
  )
  statuses <- vapply(viewer$rendered$links, function(x) x$status, character(1))
  expect_true(length(statuses) >= 2L)
  expect_true(all(statuses == "ok"))
  expect_true(any(grepl("init_study_paths", vapply(viewer$rendered$links, function(x) x$display, character(1)))))
  expect_true(any(grepl("mk_tab_1", vapply(viewer$rendered$links, function(x) x$display, character(1)))))
  expect_false(any(grepl("code-file-link--outside_root", viewer$rendered$html, fixed = TRUE)))
  expect_false(any(grepl("code-file-link--missing", viewer$rendered$html, fixed = TRUE)))
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

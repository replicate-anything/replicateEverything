test_that("save_local_shiny copies app and www", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  dest <- tempfile("shiny-deploy-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  save_local_shiny(dest)

  expect_true(file.exists(file.path(dest, "app.R")))
  expect_true(file.exists(file.path(dest, "www", "logo-hex.png")))
  expect_true(file.exists(file.path(dest, "local.R.example")))
  expect_true(file.exists(file.path(dest, "deploy-options.R")))
  expect_equal(readLines(file.path(dest, "deploy-options.R")), "options(replicate_shiny.live_run = TRUE)")
})

test_that("save_local_shiny with live_run=FALSE writes display-only deploy-options", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  dest <- tempfile("shiny-deploy-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  save_local_shiny(dest, live_run = FALSE)

  opts_path <- file.path(dest, "deploy-options.R")
  expect_true(file.exists(opts_path))
  expect_equal(readLines(opts_path), "options(replicate_shiny.live_run = FALSE)")
})

test_that("shiny_live_run_enabled reads replicate_shiny.live_run option", {
  withr::with_options(list(replicate_shiny.live_run = NULL), {
    expect_true(shiny_live_run_enabled())
  })
  withr::with_options(list(replicate_shiny.live_run = FALSE), {
    expect_false(shiny_live_run_enabled())
  })
  withr::with_options(list(replicate_shiny.live_run = TRUE), {
    expect_true(shiny_live_run_enabled())
  })
})

test_that("save_local_shiny does not overwrite local.R", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  dest <- tempfile("shiny-deploy-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  local_r <- file.path(dest, "local.R")
  writeLines("options(replicate_shiny.keep_me = TRUE)", local_r)
  save_local_shiny(dest)
  expect_equal(readLines(local_r), "options(replicate_shiny.keep_me = TRUE)")
})

test_that("save_local_shiny does not nest when dest matches cwd tail", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  parent <- tempfile("shiny-parent-")
  deploy <- file.path(parent, "shiny_apps", "replicate")
  dir.create(deploy, recursive = TRUE)
  on.exit(unlink(parent, recursive = TRUE), add = TRUE)

  withr::with_dir(deploy, {
    out <- save_local_shiny("shiny_apps/replicate")
    expect_equal(out, normalizePath(deploy, winslash = "/", mustWork = FALSE))
    expect_true(file.exists(file.path(deploy, "app.R")))
    expect_false(dir.exists(file.path(deploy, "shiny_apps")))
  })
})

test_that("shiny_path_has_suffix detects trailing path segments", {
  expect_true(shiny_path_has_suffix("/srv/shiny_apps/replicate", "shiny_apps/replicate"))
  expect_false(shiny_path_has_suffix("/srv/shiny", "shiny_apps/replicate"))
})

test_that("parse_shiny_query_string reads doi and optional fields", {
  skip_if_not(requireNamespace("shiny", quietly = TRUE), "shiny not installed")
  parsed <- parse_shiny_query_string("?doi=10.1017%2Fs0003055426101749&what=tab_1&language=stata")
  expect_equal(parsed$doi, "10.1017/s0003055426101749")
  expect_equal(parsed$what, "tab_1")
  expect_equal(parsed$language, "stata")
})

test_that("parse_shiny_deep_link_from_search ignores empty search", {
  expect_null(parse_shiny_deep_link_from_search(""))
  expect_null(parse_shiny_deep_link_from_search("?"))
})

test_that("parse_shiny_deep_link_from_search extracts doi without base path", {
  link <- parse_shiny_deep_link_from_search("?doi=10.1017/s0003055426101749")
  expect_equal(link$doi, "10.1017/s0003055426101749")
  expect_equal(link$what, "")
  expect_equal(link$language, "")
})

test_that("extract_shiny_deep_link returns NULL without doi", {
  expect_null(extract_shiny_deep_link(list(what = "tab_1")))
})

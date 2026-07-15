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
  opts <- readLines(file.path(dest, "deploy-options.R"))
  expect_true(any(grepl("replicate_shiny.live_run = TRUE", opts)))
  expect_true(any(grepl("replicate_shiny.feedback_enabled = TRUE", opts)))
  expect_true(any(grepl("replicate_shiny.feedback_in_app_enabled = TRUE", opts)))
  expect_true(any(grepl("replicate_shiny.feedback_file", opts)))
  app_lines <- readLines(file.path(dest, "app.R"), warn = FALSE)
  expect_true(any(grepl("BAKED_DEPLOY_OPTIONS_START", app_lines, fixed = TRUE)))
  expect_true(any(grepl("replicate_shiny.feedback_enabled = TRUE", app_lines)))
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
  opts <- readLines(opts_path)
  expect_true(any(grepl("replicate_shiny.live_run = FALSE", opts)))
  # Server default: feedback stays on unless explicitly disabled
  expect_true(any(grepl("replicate_shiny.feedback_enabled = TRUE", opts)))
  app_lines <- readLines(file.path(dest, "app.R"), warn = FALSE)
  expect_true(any(grepl("replicate_shiny.live_run = FALSE", app_lines)))
})

test_that("save_local_shiny can disable feedback via arg", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  dest <- tempfile("shiny-deploy-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  save_local_shiny(dest, feedback_enabled = FALSE)
  opts <- readLines(file.path(dest, "deploy-options.R"))
  expect_true(any(grepl("replicate_shiny.feedback_enabled = FALSE", opts)))
  expect_true(any(grepl("replicate_shiny.feedback_in_app_enabled = FALSE", opts)))
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

test_that("coerce_shiny_deep_link accepts list and named vector payloads", {
  from_list <- coerce_shiny_deep_link(list(
    doi = "10.1017/s0003055426101749",
    what = "tab_1",
    language = "stata"
  ))
  expect_equal(from_list$doi, "10.1017/s0003055426101749")
  expect_equal(from_list$what, "tab_1")
  expect_equal(from_list$language, "stata")

  from_named <- coerce_shiny_deep_link(c(
    doi = "10.1017/s0003055426101749",
    what = "tab_1",
    language = ""
  ))
  expect_equal(from_named$doi, "10.1017/s0003055426101749")
  expect_equal(from_named$what, "tab_1")
  expect_equal(from_named$language, "")

  from_scalar <- coerce_shiny_deep_link("10.1017/s0003055426101749")
  expect_equal(from_scalar$doi, "10.1017/s0003055426101749")
  expect_null(coerce_shiny_deep_link(list(what = "tab_1")))
})

test_that("app.R onFlushed callbacks do not call invalidateLater", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  lines <- readLines(file.path(src, "app.R"), warn = FALSE)
  depth <- 0L
  in_on_flushed <- FALSE
  for (line in lines) {
    if (!in_on_flushed && grepl("onFlushed\\s*\\(", line)) {
      in_on_flushed <- TRUE
      depth <- 0L
    }
    if (!in_on_flushed) {
      next
    }
    depth <- depth + nchar(gsub("[^{]", "", line)) - nchar(gsub("[^}]", "", line))
    expect_false(
      grepl("invalidateLater\\s*\\(", line),
      info = "invalidateLater requires a reactive consumer; onFlushed is not one"
    )
    if (depth <= 0L && grepl("\\}", line)) {
      in_on_flushed <- FALSE
    }
  }
})

test_that("app.R isolates clientData reads when arming welcome from onFlushed", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  text <- paste(readLines(file.path(src, "app.R"), warn = FALSE), collapse = "\n")
  expect_match(
    text,
    "isolate\\s*\\(\\s*session\\$clientData\\$url_search\\s*\\)",
    perl = TRUE
  )
  expect_match(text, "welcome_defer_until\\s*<-\\s*reactiveVal")
})

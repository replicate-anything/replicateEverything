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
  expect_true(any(grepl("replicate_shiny.wzb_live_run_max_seconds = 600L", opts)))
  app_lines <- readLines(file.path(dest, "app.R"), warn = FALSE)
  expect_true(any(grepl("BAKED_DEPLOY_OPTIONS_START", app_lines, fixed = TRUE)))
  expect_true(any(grepl("replicate_shiny.feedback_enabled = TRUE", app_lines)))
  expect_true(any(grepl("replicate_shiny.wzb_live_run_max_seconds = 600L", app_lines)))
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

test_that("save_local_shiny writes configurable WZB live-run limit", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  dest <- tempfile("shiny-deploy-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  save_local_shiny(dest, wzb_live_run_max_seconds = 1200)
  opts <- readLines(file.path(dest, "deploy-options.R"))
  expect_true(any(grepl("replicate_shiny.wzb_live_run_max_seconds = 1200L", opts)))
  app_lines <- readLines(file.path(dest, "app.R"), warn = FALSE)
  expect_true(any(grepl("replicate_shiny.wzb_live_run_max_seconds = 1200L", app_lines)))
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
  expect_null(link$what)
  expect_null(link$language)
})

test_that("parse_shiny_deep_link_from_search accepts handle and ignores legacy what", {
  link <- parse_shiny_deep_link_from_search(
    "?handle=rep-template&what=tab_1&language=stata"
  )
  expect_equal(link$doi, "rep-template")
  expect_null(link$what)
  expect_null(link$language)
})

test_that("parse_shiny_deep_link_from_search ignores path prefixes and what", {
  # Host mounts under /ipi/replicate/; only the search string is parsed.
  link <- parse_shiny_deep_link_from_search(
    "?doi=10.1371%2Fjournal.pone.0278337&what=fig_1"
  )
  expect_equal(link$doi, "10.1371/journal.pone.0278337")
  expect_null(link$what)
})

test_that("extract_shiny_deep_link returns NULL without doi", {
  expect_null(extract_shiny_deep_link(list(what = "tab_1")))
})

test_that("extract_shiny_deep_link prefers doi over handle and drops what", {
  link <- extract_shiny_deep_link(list(
    doi = "10.1017/s0003055426101749",
    handle = "ignored-handle",
    what = "fig_1"
  ))
  expect_equal(link$doi, "10.1017/s0003055426101749")
  expect_null(link$what)
  expect_equal(names(link), "doi")
})

test_that("coerce_shiny_deep_link accepts list and named vector payloads", {
  from_list <- coerce_shiny_deep_link(list(
    doi = "10.1017/s0003055426101749",
    what = "tab_1",
    language = "stata"
  ))
  expect_equal(from_list$doi, "10.1017/s0003055426101749")
  expect_null(from_list$what)
  expect_equal(names(from_list), "doi")

  from_named <- coerce_shiny_deep_link(c(
    doi = "10.1017/s0003055426101749",
    what = "tab_1",
    language = ""
  ))
  expect_equal(from_named$doi, "10.1017/s0003055426101749")
  expect_null(from_named$what)

  from_scalar <- coerce_shiny_deep_link("10.1017/s0003055426101749")
  expect_equal(from_scalar$doi, "10.1017/s0003055426101749")
  expect_null(coerce_shiny_deep_link(list(what = "tab_1")))
  from_handle <- coerce_shiny_deep_link(list(handle = "rep-template", what = "tab_1"))
  expect_equal(from_handle$doi, "rep-template")
  expect_null(from_handle$what)
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

test_that("app.R surfaces a local-study choice and hint text in the DOI picker", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  lines <- readLines(file.path(src, "app.R"), warn = FALSE)
  text <- paste(lines, collapse = "\n")

  # Pinned dropdown choice helper is defined ...
  expect_match(text, "local_study_select_choice\\s*<-\\s*function")
  # ... and referenced in both the initial UI and the server-side choices
  # refresh, so a local study checkout is discoverable in the dropdown, not
  # only by typing "local" from memory.
  expect_gte(sum(grepl("local_study_select_choice()", lines, fixed = TRUE)), 2L)

  # DOI/path free-text field and inline help both mention "local" explicitly.
  expect_true(any(grepl('placeholder', lines, fixed = TRUE) &
    grepl("local", lines, fixed = TRUE)))
  expect_true(any(grepl("type or select", lines, fixed = TRUE) &
    grepl("local", lines, fixed = TRUE)))

  # resolve_study_doi_input already treats blank / "local" input as the
  # working-directory study for both dropdown and free-text submission paths.
  expect_true(any(grepl('doi_input <- "local"', lines, fixed = TRUE)))
})

test_that("local_study_select_choice falls back to character(0) when no local study is found", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  # Extract just the helper (avoids sourcing the rest of app.R, which runs
  # top-level Shiny startup / registry configuration side effects).
  lines <- readLines(file.path(src, "app.R"), warn = FALSE)
  start <- grep("^local_study_select_choice <- function", lines)
  skip_if(length(start) == 0L, "local_study_select_choice not found in app.R")
  depth <- 0L
  end <- start
  for (i in seq(start, length(lines))) {
    depth <- depth + nchar(gsub("[^{]", "", lines[[i]])) - nchar(gsub("[^}]", "", lines[[i]]))
    if (depth <= 0L && i > start) {
      end <- i
      break
    }
  }
  fn_env <- new.env(parent = globalenv())
  fn_env$`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
  fn_env$truncate_label <- function(text, max_chars = 40L) as.character(text)[[1]]
  fn_env$replicate_fn <- function(name, ...) {
    if (identical(name, "find_local_study_root")) {
      return(NULL)
    }
    NULL
  }
  eval(parse(text = lines[start:end]), envir = fn_env)
  expect_identical(fn_env$local_study_select_choice(), character(0))
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
  expect_match(text, "isolate\\s*\\(\\s*welcome_defer_until\\s*\\(")
  expect_match(text, "deep_link_flags\\s*<-\\s*new\\.env")
})

test_that("app.R defers deep-link apply until Studies cache is ready", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  text <- paste(readLines(file.path(src, "app.R"), warn = FALSE), collapse = "\n")
  # Cold paste: queue ?doi= before onFlushed loads shiny_studies.json.
  expect_match(
    text,
    "observeEvent\\s*\\(\\s*list\\s*\\(\\s*state\\$pending_deep_link_doi\\s*,\\s*registry_ready\\s*\\(\\s*\\)\\s*\\)",
    perl = TRUE
  )
  expect_match(text, "if\\s*\\(\\s*!\\s*isTRUE\\s*\\(\\s*registry_ready\\s*\\(\\s*\\)\\s*\\)\\s*\\)")
  expect_match(text, "preserve_selected")
  expect_match(text, "popstate")
  expect_match(text, "params\\.get\\('handle'\\)")
})

test_that("app.R study deep links are study-only and dropdown is not blocked", {
  src <- shiny_app_dir()
  skip_if_not(nzchar(src) && dir.exists(src), "inst/shiny not available")

  text <- paste(readLines(file.path(src, "app.R"), warn = FALSE), collapse = "\n")

  # No table/figure deep-link race machinery.
  expect_false(grepl("pending_deep_link_what", text, fixed = TRUE))
  expect_false(grepl("pending_deep_link_language", text, fixed = TRUE))
  expect_false(grepl("apply_pending_deep_link_what", text, fixed = TRUE))
  expect_false(grepl("study_keys_match", text, fixed = TRUE))

  # URL helper emits doi only (no what=/language= args).
  expect_match(
    text,
    "shiny_deep_link_query_list\\s*<-\\s*function\\s*\\(\\s*doi\\s*\\)",
    perl = TRUE
  )
  expect_false(grepl("shiny_deep_link_query_list\\([^)]*what\\s*=", text))

  # Manual dropdown clears pending then always load_study (highest priority).
  # Must not early-return when pending_deep_link_doi is set.
  expect_match(
    text,
    paste0(
      "observeEvent\\s*\\(\\s*input\\$study_select\\s*,\\s*\\{[\\s\\S]*?",
      "state\\$pending_deep_link_doi\\s*<-\\s*NULL[\\s\\S]*?",
      "load_study\\s*\\(\\s*input\\$study_select"
    ),
    perl = TRUE
  )
  expect_false(
    grepl(
      paste0(
        "observeEvent\\s*\\(\\s*input\\$study_select\\s*,\\s*\\{[\\s\\S]*?",
        "pending\\s*<-\\s*isolate\\s*\\(\\s*state\\$pending_deep_link_doi\\s*\\)[\\s\\S]*?",
        "return\\s*\\(\\s*invisible\\s*\\(\\s*NULL\\s*\\)\\s*\\)"
      ),
      text,
      perl = TRUE
    )
  )
})

test_that("format_function_candidates includes stata and base names", {
  rep <- list(
    id = "tab_2",
    type = "table",
    engine = "stata",
    format = "code/helpers/format_stata.R"
  )
  expect_equal(
    replicateEverything:::format_function_candidates(rep),
    c("format_tab_2_stata", "format_tab_2")
  )
})

test_that("resolve_format_function uses default when no format_* exists", {
  rep <- list(
    id = "tab_9",
    type = "table",
    engine = "r",
    format = "format_tab_9"
  )
  env <- new.env(parent = emptyenv())
  fn <- replicateEverything:::resolve_format_function(env, rep)
  out <- fn("plain text")
  expect_equal(out, "plain text")
})

test_that("default_format_object wraps a stata log file", {
  tmp <- withr::local_tempfile(fileext = ".log")
  writeLines(c(". summarize x", "Variable | Obs"), tmp)
  rep <- list(id = "tab_1", type = "table", engine = "stata")
  html <- replicateEverything:::default_format_object(tmp, rep)
  expect_true(grepl("<pre", html, fixed = TRUE))
  expect_true(grepl("summarize x", html, fixed = TRUE))
})

test_that("default_format_object finds format_tab_N_stata from helper script", {
  study <- fixture_stata_study_root()
  log <- file.path(study, "artifacts", "staging", "tab_2_stata.log")
  skip_if_not(file.exists(log), "fixture staging log missing")

  withr::with_options(
    list(replicateEverything.study_folders_root = dirname(study)),
    {
      rep <- list(
        id = "tab_2",
        type = "table",
        engine = "stata",
        format = "code/helpers/format_stata.R",
        code = "code/tab_2.do"
      )
      ctx <- list(
        doi = fixture_stata_doi(),
        local_root = normalizePath(study, winslash = "/", mustWork = FALSE)
      )
      env <- new.env(parent = globalenv())
      replicateEverything:::source_replication_scripts(
        rep, ctx, env, install_deps = FALSE, include_format = TRUE
      )
      fn <- replicateEverything:::resolve_format_function(env, rep)
      html <- fn(list(output_path = log))
      expect_true(grepl("<pre", html))
      expect_true(grepl("summarize x", html, fixed = TRUE))
    }
  )
})

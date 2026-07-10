test_that("infer_stata_source_paths skips setup helpers", {
  wrapper <- c(
    'do "code/helpers/init_study_paths.do"',
    'do "${maindir}/code/tables/mk_tab_2.do"'
  )
  paths <- replicateEverything:::infer_stata_source_paths(wrapper)
  expect_equal(paths, "code/tables/mk_tab_2.do")
})

test_that("get_code inlines Jiang Stata table source", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-s0003055426101749")
  testthat::skip_if_not(dir.exists(study_dir), "Jiang study repo missing")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  code <- get_code("10.1017/S0003055426101749", "tab_2", language = "stata")
  text <- paste(code, collapse = "\n")
  expect_true(grepl("ANALYSIS", text, fixed = TRUE))
  expect_true(grepl("mk_tab_2.do", text, fixed = TRUE))
  expect_true(grepl("promotion_step", text, fixed = TRUE))
  expect_false(grepl('do "${maindir}/code/tables/mk_tab_2.do"', text, fixed = TRUE))
})

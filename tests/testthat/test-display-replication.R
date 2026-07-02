test_that("get_code assembles runnable Stata with substantive source", {
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
  text <- paste(code, collapse = "\n")
  testthat::expect_true(grepl("ANALYSIS", text, fixed = TRUE))
  testthat::expect_true(grepl("esttab", text, fixed = TRUE))
  testthat::expect_false(grepl("format_tab_1", text, fixed = TRUE))
})

test_that("get_code for colonial origins exposes MIT maketable source", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1257-aer.91.5.1369")
  testthat::skip_if_not(dir.exists(study_dir), "Colonial origins study missing")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  stata_code <- get_code("10.1257/aer.91.5.1369", "tab_1_stata")
  stata_text <- paste(stata_code, collapse = "\n")
  testthat::expect_true(grepl("ANALYSIS", stata_text, fixed = TRUE))
  testthat::expect_true(grepl("summ logpgp95", stata_text, fixed = TRUE))
  testthat::expect_false(grepl("format_stata", stata_text, fixed = TRUE))

  r_code <- get_code("10.1257/aer.91.5.1369", "tab_1")
  r_text <- paste(r_code, collapse = "\n")
  testthat::expect_true(grepl("make_tab_1", r_text, fixed = TRUE))
  testthat::expect_false(grepl("summ logpgp95", r_text, fixed = TRUE))
})

test_that("load_replication_for_display prefers artifact when present", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1257-aer.91.5.1369")
  testthat::skip_if_not(
    file.exists(file.path(study_dir, "artifacts", "tab_2.html")),
    "tab_2 artifact missing"
  )

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  out <- load_replication_for_display(
    "10.1257/aer.91.5.1369",
    "tab_2",
    prefer = "artifact",
    fallback_live = FALSE
  )
  testthat::expect_true(out$ok)
  testthat::expect_equal(out$source, "artifact")
  testthat::expect_true(is.character(out$value))
})

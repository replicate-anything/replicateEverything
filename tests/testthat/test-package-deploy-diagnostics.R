test_that("package_deploy_diagnostics reports installed package", {
  skip_if_not_installed("replicateEverything")
  out <- package_deploy_diagnostics(print = FALSE)
  expect_match(out$version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  expect_true(is.character(out$library_path))
  expect_true(length(out$lib_paths) >= 1L)
  expect_true(is.logical(out$functions))
  expect_true("shiny_feedback_github_category_url" %in% names(out$functions))
  expect_true(out$functions[["shiny_feedback_github_category_url"]])
})

test_that("package_deploy_diagnostics detects deploy bundle stamp", {
  skip_if_not_installed("replicateEverything")
  dest <- tempfile("shiny-deploy-diag-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  save_local_shiny(dest)
  out <- package_deploy_diagnostics(dest, print = FALSE)
  expect_equal(out$deploy_dir, normalizePath(dest, winslash = "/", mustWork = FALSE))
  expect_true(nzchar(out$app_sha %||% ""))
  expect_false(isTRUE(out$app_stale))
})

test_that("write_shiny_deploy_options stamps version and library path", {
  skip_if_not_installed("replicateEverything")
  dest <- tempfile("shiny-deploy-opts-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  write_shiny_deploy_options(dest)
  lines <- readLines(file.path(dest, "deploy-options.R"))
  expect_true(any(grepl("^# Deploy stamp:", lines)))
  expect_true(any(grepl("replicate_shiny.deploy_pkg_version", lines, fixed = TRUE)))
  expect_true(any(grepl("replicate_shiny.deploy_lib", lines, fixed = TRUE)))
})

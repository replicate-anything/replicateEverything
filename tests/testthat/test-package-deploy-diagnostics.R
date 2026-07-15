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
  info <- package_build_info("replicateEverything")
  expect_true(any(grepl("^# Deploy stamp:", lines)))
  expect_true(any(grepl("replicate_shiny.deploy_pkg_version", lines, fixed = TRUE)))
  expect_true(any(grepl("replicate_shiny.deploy_lib", lines, fixed = TRUE)))
  expect_true(any(grepl(info$bundled_sha %||% "", lines, fixed = TRUE)))
})

test_that("package_deploy_diagnostics ignores legacy RemoteSha deploy stamp mismatch", {
  skip_if_not_installed("replicateEverything")
  dest <- tempfile("shiny-deploy-diag-legacy-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  info <- package_build_info("replicateEverything")
  bundled <- info$bundled_sha
  skip_if_not(nzchar(bundled %||% ""))

  writeLines("abc9999", file.path(dest, "BUNDLE_SHA"), useBytes = TRUE)
  writeLines(
    c(
      sprintf(
        'options(replicate_shiny.deploy_pkg_version = "%s")',
        info$version
      ),
      'options(replicate_shiny.deploy_pkg_sha = "abc9999")',
      sprintf(
        'options(replicate_shiny.deploy_lib = "%s")',
        gsub("\\", "/", package_library_path("replicateEverything"), fixed = TRUE)
      )
    ),
    file.path(dest, "deploy-options.R"),
    useBytes = TRUE
  )

  out <- package_deploy_diagnostics(dest, print = FALSE)
  expect_false(isTRUE(out$app_stale))
  expect_true(isTRUE(out$app_bundle_mismatch))
  expect_true(out$functions[["shiny_feedback_github_category_url"]])
})

test_that("read_deploy_stamp_options parses deploy-options.R without sourcing", {
  dest <- tempfile("shiny-deploy-stamp-")
  dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      'options(replicate_shiny.deploy_pkg_version = "0.6.2")',
      'options(replicate_shiny.deploy_pkg_sha = "deadbeef")',
      'options(replicate_shiny.deploy_lib = "/tmp/replicateEverything")'
    ),
    file.path(dest, "deploy-options.R"),
    useBytes = TRUE
  )

  stamp <- replicateEverything:::read_deploy_stamp_options(dest)
  expect_equal(stamp$version, "0.6.2")
  expect_equal(stamp$sha, "deadbeef")
  expect_equal(stamp$lib, "/tmp/replicateEverything")
})

test_that("get_package_namespace_fn resolves internal feedback helpers", {
  skip_if_not_installed("replicateEverything")
  fn <- replicateEverything:::get_package_namespace_fn(
    "shiny_feedback_github_category_url",
    aliases = "shiny_feedback_category_url"
  )
  expect_true(is.function(fn))
  url <- fn("bug")
  expect_true(grepl("/issues/new", url, fixed = TRUE))
})

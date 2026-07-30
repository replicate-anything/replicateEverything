test_that("package_build_info returns version and optional sha", {
  skip_if_not_installed("replicateEverything")
  info <- package_build_info("replicateEverything")
  expect_match(info$version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  expect_true(is.character(info$sha))
  expect_true(is.character(info$bundled_sha))
  expect_true(is.character(info$remote_sha))
  expect_true(is.character(info$source))
  expect_equal(info$sha, info$bundled_sha)
})

test_that("format_shiny_deploy_stale_note is silent when versions match", {
  expect_null(
    replicateEverything:::format_shiny_deploy_stale_note(
      version_stale = FALSE,
      deploy_version = "0.7.35",
      installed_version = "0.7.35"
    )
  )
  # Stale flag alone is not enough if the strings already agree.
  expect_null(
    replicateEverything:::format_shiny_deploy_stale_note(
      version_stale = TRUE,
      deploy_version = "0.7.35",
      installed_version = "0.7.35"
    )
  )
})

test_that("format_shiny_deploy_stale_note names version clash briefly", {
  note <- replicateEverything:::format_shiny_deploy_stale_note(
    version_stale = TRUE,
    deploy_version = "0.7.34",
    installed_version = "0.7.35"
  )
  expect_identical(
    note,
    "stamp version: 0.7.34 · installed: 0.7.35 [possibly stale]"
  )
})

test_that("format_shiny_deploy_stale_note can combine mismatch kinds", {
  note <- replicateEverything:::format_shiny_deploy_stale_note(
    version_stale = TRUE,
    deploy_version = "0.7.34",
    installed_version = "0.7.35",
    deploy_lib_stale = TRUE,
    namespace_stale = TRUE
  )
  expect_match(note, "stamp version: 0\\.7\\.34")
  expect_match(note, "installed: 0\\.7\\.35")
  expect_match(note, "loaded namespace")
  expect_match(note, "deploy lib")
})

test_that("read_build_sha_file reads bundled shiny stamp", {
  path <- system.file("shiny", "BUNDLE_SHA", package = "replicateEverything")
  skip_if_not(nzchar(path))
  sha <- replicateEverything:::read_build_sha_file(path)
  expect_match(sha, "^[0-9a-f]{7}$")
})

test_that("write_shiny_bundle_sha writes bundled package stamp", {
  skip_if_not_installed("replicateEverything")
  bundled <- replicateEverything:::package_bundled_sha("replicateEverything")
  skip_if_not(nzchar(bundled %||% ""))
  tmp <- tempfile("shiny-deploy-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  sha <- replicateEverything:::write_shiny_bundle_sha(tmp)
  expect_true(file.exists(file.path(tmp, "BUNDLE_SHA")))
  expect_equal(sha, bundled)
  expect_equal(
    replicateEverything:::read_build_sha_file(file.path(tmp, "BUNDLE_SHA")),
    bundled
  )
})

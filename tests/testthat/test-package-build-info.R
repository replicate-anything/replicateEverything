test_that("package_build_info returns version and optional sha", {
  skip_if_not_installed("replicateEverything")
  info <- package_build_info("replicateEverything")
  expect_match(info$version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  expect_true(is.character(info$sha))
  expect_true(is.character(info$source))
})

test_that("read_build_sha_file reads bundled shiny stamp", {
  path <- system.file("shiny", "BUNDLE_SHA", package = "replicateEverything")
  skip_if_not(nzchar(path))
  sha <- replicateEverything:::read_build_sha_file(path)
  expect_match(sha, "^[0-9a-f]{7}$")
})

test_that("write_shiny_bundle_sha creates BUNDLE_SHA in deploy dir", {
  tmp <- tempfile("shiny-deploy-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  sha <- replicateEverything:::write_shiny_bundle_sha(tmp)
  expect_true(file.exists(file.path(tmp, "BUNDLE_SHA")))
  expect_equal(
    replicateEverything:::read_build_sha_file(file.path(tmp, "BUNDLE_SHA")),
    sha
  )
})

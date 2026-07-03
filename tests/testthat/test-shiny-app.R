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

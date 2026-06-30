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

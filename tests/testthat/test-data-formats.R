test_that("read_data_path reads dta when haven is available", {
  skip_if_not_installed("haven")
  fixture_dta <- normalizePath(
    file.path(testthat::test_path(".."), "fixtures", "data", "tiny.dta"),
    winslash = "/",
    mustWork = FALSE
  )
  if (!file.exists(fixture_dta)) {
    dir.create(dirname(fixture_dta), recursive = TRUE, showWarnings = FALSE)
    haven::write_dta(
      data.frame(x = seq_len(100), y = rep(letters, length.out = 100)),
      fixture_dta
    )
  }
  df <- read_data_path(fixture_dta, "dta")
  expect_true(nrow(df) >= 100)
})

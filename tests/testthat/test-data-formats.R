test_that("read_data_path reads dta when haven is available", {
  skip_if_not_installed("haven")
  fixture_dta <- normalizePath(
    file.path(
      testthat::test_path(
        "..", "..", "..", "rep-10.1017-S0003055403000534", "data", "repdata.dta"
      )
    ),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(file.exists(fixture_dta), "Fearon replication data not available")
  df <- read_data_path(fixture_dta, "dta")
  expect_true(nrow(df) > 1000)
})

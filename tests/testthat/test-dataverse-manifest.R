test_that("normalize_dataverse_persistent_id adds doi prefix", {
  expect_equal(
    normalize_dataverse_persistent_id("10.7910/DVN/BZOCDJ"),
    "doi:10.7910/DVN/BZOCDJ"
  )
  expect_equal(
    normalize_dataverse_persistent_id("doi:10.7910/DVN/BZOCDJ"),
    "doi:10.7910/DVN/BZOCDJ"
  )
})

test_that("extract_dataverse_deposit_archive restores layout from zip", {
  zip <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "_tmp_bzocdj_original.zip"),
    winslash = "/",
    mustWork = FALSE
  )
  testthat::skip_if_not(file.exists(zip), "BZOCDJ original zip not present (run archive test once)")
  deposit <- file.path(tempdir(), "deposit_extract_test")
  unlink(deposit, recursive = TRUE, force = TRUE)
  extract_dataverse_deposit_archive(zip, deposit, clean = TRUE)
  expect_true(file.exists(file.path(deposit, "data", "study1.csv")))
  expect_true(file.exists(file.path(deposit, "scripts", "recodes_s1.R")))
  expect_true(file.exists(file.path(deposit, "ReadMe.txt")))
})

test_that("verify_deposit_paths catches missing files", {
  tmp <- tempfile("deposit_verify")
  dir.create(tmp)
  expect_error(
    verify_deposit_paths(c("data/study1.csv"), tmp),
    "missing expected files"
  )
})

test_that("manifest_row_use_original detects true values", {
  row <- data.frame(original = TRUE, stringsAsFactors = FALSE)
  expect_true(manifest_row_use_original(row))
  row2 <- data.frame(original = "true", stringsAsFactors = FALSE)
  expect_true(manifest_row_use_original(row2))
  row3 <- data.frame(original = FALSE, stringsAsFactors = FALSE)
  expect_false(manifest_row_use_original(row3))
})

test_that("build_dataverse_manifest_from_dataset maps originalFileName", {
  testthat::skip_if_not_installed("dataverse")
  withr::local_envvar(DATAVERSE_SERVER = "dataverse.harvard.edu")
  manifest <- build_dataverse_manifest_from_dataset(
    "doi:10.7910/DVN/BZOCDJ",
    paths = c("study1.tab", "recodes_s1.R")
  )
  study_row <- manifest[manifest$dataverse_file == "study1.tab", , drop = FALSE]
  expect_equal(nrow(study_row), 1L)
  expect_equal(study_row$path[[1]], "study1.csv")
  expect_true(isTRUE(study_row$original[[1]]) || study_row$original[[1]] == TRUE)
  script_row <- manifest[manifest$dataverse_file == "recodes_s1.R", , drop = FALSE]
  expect_equal(script_row$path[[1]], "recodes_s1.R")
  expect_false(manifest_row_use_original(script_row))
})

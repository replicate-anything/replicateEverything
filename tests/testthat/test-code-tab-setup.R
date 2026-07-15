blair_root <- normalizePath(
  file.path(testthat::test_path(".."), "..", "..", "rep-10.1017-s0003055422000284"),
  winslash = "/",
  mustWork = FALSE
)
velez_root <- normalizePath(
  file.path(testthat::test_path(".."), "..", "..", "rep-10.1017-s0003055426101622"),
  winslash = "/",
  mustWork = FALSE
)

test_that("github_repo_zip_url builds main branch archive link", {
  expect_equal(
    replicateEverything:::github_repo_zip_url("replicate-anything/rep-example"),
    "https://github.com/replicate-anything/rep-example/archive/refs/heads/main.zip"
  )
})

test_that("code_setup_open_instruction is engine-aware for multi-engine studies", {
  expect_match(
    replicateEverything:::code_setup_open_instruction("stata", c("r", "stata")),
    "R or Stata"
  )
  expect_match(
    replicateEverything:::code_setup_open_instruction("r", "r"),
    "^Open R "
  )
})

test_that("code_setup_box_content describes Blair Stata table setup", {
  testthat::skip_if_not(dir.exists(blair_root), "Blair study repo missing")
  opts <- replicateEverything:::folder_study_run_options(blair_root, yaml::read_yaml(file.path(blair_root, "replication.yml")))
  old <- options(replicateEverything.index = opts$replicateEverything.index)
  on.exit(options(replicateEverything.index = old$replicateEverything.index), add = TRUE)

  content <- replicateEverything:::code_setup_box_content(
    doi = "10.1017/S0003055422000284",
    language = "stata",
    step_id = "tab_1"
  )

  expect_equal(content$repo_slug, "replicate-anything/rep-10.1017-s0003055422000284")
  expect_match(content$zip_url, "/archive/refs/heads/main\\.zip$")
  expect_match(paste(content$step1, collapse = " "), "R or Stata")
  expect_true(any(grepl("Stata:", content$step2, fixed = TRUE)))
  expect_true(any(grepl("estout", content$step2, fixed = TRUE)))
  expect_true(any(grepl("Dataverse", content$step2_prep, fixed = TRUE)))
  expect_match(content$step3, "Stata session")
})

test_that("code_setup_box_content describes Velez R table setup", {
  testthat::skip_if_not(dir.exists(velez_root), "Velez study repo missing")
  opts <- replicateEverything:::folder_study_run_options(velez_root, yaml::read_yaml(file.path(velez_root, "replication.yml")))
  old <- options(replicateEverything.index = opts$replicateEverything.index)
  on.exit(options(replicateEverything.index = old$replicateEverything.index), add = TRUE)

  content <- replicateEverything:::code_setup_box_content(
    doi = "10.1017/S0003055426101622",
    language = "r",
    step_id = "tab_1"
  )

  expect_equal(content$repo_slug, "replicate-anything/rep-10.1017-s0003055426101622")
  expect_match(tail(content$step1, 1L), "^Open R ")
  expect_false(grepl("Stata", tail(content$step1, 1L), fixed = TRUE))
  expect_true(any(grepl("^R:", content$step2)))
  expect_true(any(grepl("tidyverse", content$step2, fixed = TRUE)))
  expect_match(content$step3, "R session")
})

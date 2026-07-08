test_that("default artifact path uses png for figures", {
  rep <- list(type = "figure")
  expect_equal(default_artifact_path(rep, "fig_1"), "artifacts/fig_1.png")
})

test_that("default artifact path uses rds when format is specified", {
  rep <- list(type = "table", format = "format_tab_1")
  expect_equal(default_artifact_path(rep, "tab_1"), "artifacts/tab_1.rds")
})

test_that("default artifact path uses html for legacy tables", {
  rep <- list(type = "table")
  expect_equal(default_artifact_path(rep, "tab_1"), "artifacts/tab_1.html")
})

test_that("registry_artifact_rel_paths uses only replication.yml artifact when set", {
  rep <- list(
    id = "tab_2",
    type = "table",
    artifact = "artifacts/tab_2.html"
  )
  paths <- registry_artifact_rel_paths("tab_2", rep, NULL)
  expect_equal(paths, "artifacts/tab_2.html")
})

test_that("get_artifact_path resolves figure png under local folder-backed study", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555_test")
  dir.create(file.path(study_dir, "artifacts"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/test",
      "replications:",
      "  - id: fig_1",
      "    type: figure",
      "    code: code/fig_1.R"
    ),
    file.path(study_dir, "replication.yml")
  )
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/test",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555_test",
      "  study_folder: rep-10.5555_test",
      "repo: replicate-anything/rep-10.5555_test"
    ),
    file.path(local_root, "studies", "10.5555_test.yml")
  )
  png_path <- file.path(study_dir, "artifacts", "fig_1.png")
  writeBin(as.raw(0), png_path)

  local_index <- data.frame(
    folder = "10.5555_test",
    doi = "10.5555/test",
    title = "Test",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/rep-10.5555_test",
    stringsAsFactors = FALSE
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = local_root,
      replicateEverything.study_folders_root = local_root,
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.index = local_index
    ),
    {
      path <- get_artifact_path("10.5555/test", "fig_1")
      expect_equal(
        normalizePath(path, winslash = "/", mustWork = FALSE),
        normalizePath(png_path, winslash = "/", mustWork = FALSE)
      )
      expect_true(artifact_available("10.5555/test", "fig_1"))
      expect_silent(validate_artifact("10.5555/test", "fig_1"))
    }
  )
})

test_that("validate_artifact fails when file is missing", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555_missing")
  dir.create(file.path(study_dir, "artifacts"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/missing",
      "replications:",
      "  - id: fig_1",
      "    type: figure",
      "    code: code/fig_1.R"
    ),
    file.path(study_dir, "replication.yml")
  )
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/missing",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555_missing",
      "  study_folder: rep-10.5555_missing",
      "repo: replicate-anything/rep-10.5555_missing"
    ),
    file.path(local_root, "studies", "10.5555_missing.yml")
  )

  local_index <- data.frame(
    folder = "10.5555_missing",
    doi = "10.5555/missing",
    title = "Test",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/rep-10.5555_missing",
    stringsAsFactors = FALSE
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = local_root,
      replicateEverything.study_folders_root = local_root,
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.index = local_index
    ),
    {
      expect_false(artifact_available("10.5555/missing", "fig_1"))
      expect_error(
        validate_artifact("10.5555/missing", "fig_1"),
        "Missing artifact file"
      )
    }
  )
})

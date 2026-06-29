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

test_that("get_artifact_path resolves figure png under local registry", {
  local_root <- withr::local_tempdir()
  paper_dir <- file.path(local_root, "papers", "10.5555_test")
  dir.create(file.path(paper_dir, "artifacts"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/test",
      "replications:",
      "  - id: fig_1",
      "    type: figure",
      "    script: code/fig_1.R"
    ),
    file.path(paper_dir, "replication.yml")
  )
  png_path <- file.path(paper_dir, "artifacts", "fig_1.png")
  writeBin(as.raw(0), png_path)

  withr::with_options(
    list(replicateEverything.registry_root = local_root),
    {
      path <- get_artifact_path("10.5555/test", "fig_1")
      expect_equal(path, png_path)
      expect_true(artifact_available("10.5555/test", "fig_1"))
      expect_silent(validate_artifact("10.5555/test", "fig_1"))
    }
  )
})

test_that("validate_artifact fails when file is missing", {
  local_root <- withr::local_tempdir()
  paper_dir <- file.path(local_root, "papers", "10.5555_missing")
  dir.create(file.path(paper_dir, "artifacts"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/missing",
      "replications:",
      "  - id: fig_1",
      "    type: figure",
      "    script: code/fig_1.R"
    ),
    file.path(paper_dir, "replication.yml")
  )

  withr::with_options(
    list(replicateEverything.registry_root = local_root),
    {
      expect_false(artifact_available("10.5555/missing", "fig_1"))
      expect_error(
        validate_artifact("10.5555/missing", "fig_1"),
        "Missing artifact file"
      )
    }
  )
})

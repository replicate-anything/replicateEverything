test_that("default artifact path uses png for figures", {
  rep <- list(type = "figure")
  expect_equal(default_artifact_path(rep, "fig_1"), "outputs/fig_1.png")
})

test_that("default artifact path uses html when format is specified", {
  rep <- list(type = "table", format = "format_tab_1")
  expect_equal(default_artifact_path(rep, "tab_1"), "outputs/tab_1.html")
})

test_that("default artifact path uses html for tables", {
  rep <- list(type = "table")
  expect_equal(default_artifact_path(rep, "tab_1"), "outputs/tab_1.html")
})

test_that("study_artifact_rel_path uses replication.yml outputs when set", {
  rep <- list(
    id = "tab_2",
    type = "table",
    outputs = list("outputs/tab_2.html")
  )
  expect_equal(study_artifact_rel_path(rep), "outputs/tab_2.html")
})

test_that("study_artifact_rel_path falls back to the type-based default", {
  expect_equal(
    study_artifact_rel_path(list(id = "fig_1", type = "figure")),
    "outputs/fig_1.png"
  )
  expect_equal(
    study_artifact_rel_path(list(id = "tab_1", type = "table")),
    "outputs/tab_1.html"
  )
})

test_that("study_artifact_rel_candidates uses outputs paths only", {
  rep <- list(
    id = "tab_1",
    type = "table",
    outputs = list("outputs/tab_1.html")
  )
  cands <- study_artifact_rel_candidates(rep)
  expect_true("outputs/tab_1.html" %in% cands)
  expect_false(any(grepl("^artifacts/", cands)))
})

test_that("get_artifact_path resolves figure png under local folder-backed study", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555-test")
  dir.create(file.path(study_dir, "outputs"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/test",
      "steps:",
      "  - id: fig_1",
      "    type: figure",
      "    code: code/fig_1.R",
      "    outputs:",
      "      - outputs/fig_1.png"
    ),
    file.path(study_dir, "replication.yml")
  )
  writeBin(as.raw(1:200), file.path(study_dir, "outputs", "fig_1.png"))
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/test",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555-test",
      "  study_folder: rep-10.5555-test",
      "repo: replicate-anything/rep-10.5555-test"
    ),
    file.path(local_root, "studies", "10.5555_test.yml")
  )
  local_index <- data.frame(
    folder = "10.5555_test",
    doi = "10.5555/test",
    title = "Test",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/rep-10.5555-test",
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
      rm(list = ls(envir = .replication_meta_cache), envir = .replication_meta_cache)
      path <- get_artifact_path("10.5555/test", "fig_1")
      expect_true(file.exists(path))
      expect_true(artifact_available("10.5555/test", "fig_1"))
    }
  )
})

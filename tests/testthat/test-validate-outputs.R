test_that("default artifact path uses png for figures", {
  rep <- list(type = "figure")
  expect_equal(default_artifact_path(rep, "fig_1"), "outputs/fig_1.png")
})

test_that("default artifact path uses html when format is specified", {
  rep <- list(type = "table", format = "format_tab_1")
  expect_equal(default_artifact_path(rep, "tab_1"), "outputs/tab_1.html")
})

test_that("default artifact path uses html for legacy tables", {
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

test_that("study_artifact_rel_path prefers outputs over deprecated artifact", {
  rep <- list(
    id = "tab_2",
    type = "table",
    outputs = list("outputs/tab_2.html"),
    artifact = "outputs/tab_2_legacy.html"
  )
  expect_equal(study_artifact_rel_path(rep), "outputs/tab_2.html")
})

test_that("study_artifact_rel_path falls back to deprecated artifact when no outputs", {
  rep <- list(
    id = "tab_2",
    type = "table",
    artifact = "outputs/tab_2.html"
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
  study_dir <- file.path(local_root, "rep-10.5555_test")
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
  png_path <- file.path(study_dir, "outputs", "fig_1.png")
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
      expect_silent(validate_outputs("10.5555/test", "fig_1"))
    }
  )
})

test_that("validate_outputs fails when file is missing", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555_missing")
  dir.create(file.path(study_dir, "outputs"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/missing",
      "steps:",
      "  - id: fig_1",
      "    type: figure",
      "    code: code/fig_1.R",
      "    outputs:",
      "      - outputs/fig_1.png"
    ),
    file.path(study_dir, "replication.yml")
  )
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/missing",
      "  materials: folder",
      "study_repo: replicate-anything/rep-10.5555_missing",
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
        validate_outputs("10.5555/missing", "fig_1"),
        "Artifact not available"
      )
    }
  )
})

test_that("validate_outputs passes for registry and study location", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555_test")
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
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/test",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555_test",
      "  study_folder: rep-10.5555_test",
      "repo: replicate-anything/rep-10.5555_test",
      "replications:",
      "  - id: fig_1",
      "    type: figure"
    ),
    file.path(local_root, "studies", "10.5555_test.yml")
  )
  png_path <- file.path(study_dir, "outputs", "fig_1.png")
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
      expect_silent(suppressMessages(
        validate_outputs(doi = "everywhere", what = "everything", registry_root = local_root)
      ))
      expect_silent(validate_outputs(location = study_dir, registry_root = local_root))
      expect_silent(validate_outputs(doi = "10.5555/test", what = "everything"))
    }
  )
})

test_that("validate_outputs everywhere accepts handle-only registry studies", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555_alt")
  dir.create(file.path(study_dir, "outputs"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  study_handle: rep-10.5555_alt",
      "  title: Alt study",
      "steps:",
      "  - id: tab_1",
      "    type: table",
      "    code: code/tab_1.R",
      "    outputs:",
      "      - outputs/tab_1.html"
    ),
    file.path(study_dir, "replication.yml")
  )
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  study_handle: rep-10.5555_alt",
      "  title: Alt study",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555_alt",
      "  study_folder: rep-10.5555_alt",
      "repo: replicate-anything/rep-10.5555_alt"
    ),
    file.path(local_root, "studies", "rep-10.5555_alt.yml")
  )
  writeLines("<table></table>", file.path(study_dir, "outputs", "tab_1.html"))

  local_index <- data.frame(
    folder = "rep-10.5555_alt",
    handle = "rep-10.5555_alt",
    doi = "",
    title = "Alt study",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/rep-10.5555_alt",
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
      expect_silent(suppressMessages(
        validate_outputs(
          doi = "everywhere",
          what = "everything",
          registry_root = local_root,
          folders = "rep-10.5555_alt"
        )
      ))
    }
  )
})

test_that("filter_replications_only_missing keeps entries without artifacts", {
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
      "      - outputs/fig_1.png",
      "  - id: tab_1",
      "    type: table",
      "    code: code/tab_1.R",
      "    artifact: outputs/tab_1.html"
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
  writeBin(as.raw(0), file.path(study_dir, "outputs", "fig_1.png"))

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
      reps <- list(
        list(id = "fig_1", type = "figure"),
        list(id = "tab_1", type = "table")
      )
      filtered <- filter_replications_only_missing(
        reps,
        "10.5555/test",
        folder = "10.5555_test",
        only_missing = TRUE
      )
      expect_length(filtered, 1L)
      expect_equal(filtered[[1]]$id, "tab_1")
    }
  )
})

test_that("build_study_outputs only_missing skips when all artifacts exist", {
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
  writeBin(as.raw(0), file.path(study_dir, "outputs", "fig_1.png"))

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
      expect_message(
        result <- build_study_outputs(
          study_dir,
          install_deps = FALSE,
          only_missing = TRUE,
          registry_root = local_root
        ),
        "All artifacts present; skipping build"
      )
      expect_length(result$manifest$replications, 0L)
    }
  )
})

test_that("build_outputs dispatch errors when doi is everywhere with single what", {
  expect_error(
    build_outputs(doi = "everywhere", what = "fig_1"),
    'When doi = "everywhere", what must be "everything" or NULL'
  )
})

test_that("build_outputs requires doi, location, or everywhere", {
  expect_error(
    build_outputs(),
    'Provide doi, location, or doi = "everywhere"'
  )
})

test_that("build_single_output only_missing skips existing artifact", {
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
  writeBin(as.raw(0), file.path(study_dir, "outputs", "fig_1.png"))

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
      expect_message(
        build_outputs(
          doi = "10.5555/test",
          what = "fig_1",
          only_missing = TRUE
        ),
        "Artifact already present for fig_1; skipping build"
      )
    }
  )
})

test_that("build_outputs location dispatch skips with only_missing", {
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
  writeBin(as.raw(0), file.path(study_dir, "outputs", "fig_1.png"))

  expect_message(
    build_outputs(
      location = study_dir,
      only_missing = TRUE,
      install_deps = FALSE
    ),
    "All artifacts present; skipping build"
  )
})

test_that("build_registry_outputs skips folder study without local repo", {
  local_root <- withr::local_tempdir()
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/remote",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555_remote",
      "  study_folder: rep-10.5555_remote",
      "repo: replicate-anything/rep-10.5555_remote",
      "replications:",
      "  - id: fig_1",
      "    type: figure"
    ),
    file.path(local_root, "studies", "10.5555_remote.yml")
  )

  local_index <- data.frame(
    folder = "10.5555_remote",
    doi = "10.5555/remote",
    title = "Test",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/rep-10.5555_remote",
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
      expect_message(
        build_registry_outputs(
          registry_root = local_root,
          folders = "10.5555_remote",
          install_deps = FALSE
        ),
        "Skipping 10.5555_remote \\(folder-backed; no local study repo\\)"
      )
    }
  )
})

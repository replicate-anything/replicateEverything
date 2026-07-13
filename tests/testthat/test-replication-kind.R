test_that("replication_kind classifies package and folder studies", {
  pkg_meta <- list(paper = list(package = "rep1371journalpone0278337"))
  expect_equal(replicateEverything:::replication_kind(pkg_meta), "package")

  folder_meta <- list(
    paper = list(materials = "folder", study_repo = "org/repo"),
    repo = "org/repo"
  )
  ctx <- list(repo = "org/repo")
  expect_equal(
    replicateEverything:::replication_kind(folder_meta, ctx),
    "folder"
  )
})

test_that("study_output_dir resolves folder studies with explicit study_path", {
  tmp <- tempfile("study-art-")
  dir.create(tmp, recursive = TRUE)
  tmp <- normalizePath(tmp, winslash = "/", mustWork = TRUE)
  dir.create(file.path(tmp, "outputs"), recursive = TRUE)
  writeLines("paper:\n  doi: https://doi.org/10.9999/test\n", file.path(tmp, "replication.yml"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  folder_meta <- list(
    paper = list(doi = "10.9999/test", study_path = tmp),
    repo = "replicate-anything/rep-10.9999_test"
  )
  expect_equal(replication_kind(folder_meta), "folder")
  expect_equal(
    normalizePath(
      replicateEverything:::resolve_study_folder_path(folder_meta),
      winslash = "/",
      mustWork = FALSE
    ),
    normalizePath(tmp, winslash = "/", mustWork = FALSE)
  )

  pkg_meta <- list(paper = list(package = "__not_installed_pkg__"))
  expect_null(replicateEverything:::study_artifact_dir(pkg_meta, NULL, installed = TRUE))
})

test_that("probe_study_engine_dependencies reads paper.dependencies", {
  meta <- list(
    paper = list(dependencies = c("stats")),
    replications = list(list(id = "tab_1", engine = "r", type = "table"))
  )
  probe <- replicateEverything:::probe_study_engine_dependencies(meta)
  expect_true(isTRUE(probe$dependencies$r$ok))
})

test_that("study_system_compatibility probes CRAN deps for package stub meta", {
  meta <- list(
    paper = list(
      package = "__not_installed_pkg__",
      dependencies = c("stats")
    ),
    replications = list(list(id = "tab_1", engine = "r", type = "table"))
  )
  probe <- replicateEverything:::probe_study_engine_dependencies(meta)
  expect_true(isTRUE(probe$dependencies$r$ok))
})

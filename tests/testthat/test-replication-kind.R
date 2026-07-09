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

test_that("study_artifact_dir returns folder and package paths", {
  tmp <- normalizePath(tempfile("study-art-"), winslash = "/", mustWork = FALSE)
  dir.create(tmp, recursive = TRUE)
  dir.create(file.path(tmp, "artifacts"), recursive = TRUE)
  writeLines("paper:\n  doi: https://doi.org/10.9999/test\n", file.path(tmp, "replication.yml"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  folder_meta <- list(paper = list(materials = "folder", doi = "10.9999/test"))
  ctx <- list(local_root = tmp, is_folder_study = TRUE)
  path <- replicateEverything:::study_artifact_dir(folder_meta, ctx, installed = FALSE)
  expect_equal(
    normalizePath(path, winslash = "/", mustWork = FALSE),
    normalizePath(file.path(tmp, "artifacts"), winslash = "/", mustWork = FALSE)
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

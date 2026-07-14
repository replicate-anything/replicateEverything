jiang_monorepo_context <- function() {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-s0003055426101749")
  registry_root <- file.path(monorepo_root, "registry")
  list(
    monorepo_root = monorepo_root,
    study_dir = study_dir,
    registry_root = registry_root,
    doi = "10.1017/s0003055426101749",
    folder = "10.1017S0003055426101749"
  )
}

test_that("Jiang study has no fig_1 step (clear DAG error)", {
  ctx <- jiang_monorepo_context()
  testthat::skip_if_not(dir.exists(ctx$study_dir), "Jiang study repo missing")
  testthat::skip_if_not(dir.exists(ctx$registry_root), "registry missing")

  withr::local_options(list(
    replicateEverything.registry_root = ctx$registry_root,
    replicateEverything.study_folders_root = ctx$monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  expect_error(
    replicateEverything::run_replication(ctx$doi, "fig_1"),
    "fig_1.*not found|Figure step ids"
  )
})

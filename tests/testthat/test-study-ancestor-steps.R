test_that("ensure_study_ancestor_steps runs missing parents from steps DAG", {
  root <- tempfile("re_ancestors_")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(file.path(root, "code"), recursive = TRUE)
  dir.create(file.path(root, "outputs"), recursive = TRUE)
  dir.create(file.path(root, "data"), recursive = TRUE)

  writeLines("1,2\n", file.path(root, "data", "raw.csv"))
  writeLines(
    c(
      "make_analysis_data <- function(data) {",
      "  dir.create('outputs', showWarnings = FALSE, recursive = TRUE)",
      "  write.csv(data.frame(x = 1), file.path('outputs', 'analysis_data.csv'), row.names = FALSE)",
      "  data.frame(x = 1)",
      "}"
    ),
    file.path(root, "code", "analysis_data.R")
  )
  writeLines(
    c(
      "tab_1 <- function(data) {",
      "  if (!file.exists(file.path('outputs', 'analysis_data.csv'))) {",
      "    stop('analysis_data output missing')",
      "  }",
      "  data",
      "}"
    ),
    file.path(root, "code", "tab_1.R")
  )
  yaml <- list(
    paper = list(doi = "10.9999/ancestor.test", study_path = root),
    steps = list(
      list(
        id = "analysis_data",
        type = "transform",
        parents = list(),
        data = "data/raw.csv",
        code = "code/analysis_data.R",
        outputs = list("outputs/analysis_data.csv"),
        engine = "r"
      ),
      list(
        id = "tab_1",
        group = "tab_1",
        type = "table",
        parents = list("analysis_data"),
        data = "outputs/analysis_data.csv",
        code = "code/tab_1.R",
        outputs = list("outputs/tab_1.html"),
        engine = "r"
      )
    )
  )
  yaml::write_yaml(yaml, file.path(root, "replication.yml"))
  replicateEverything:::configure_study_folder("10.9999/ancestor.test", root)

  meta <- yaml::read_yaml(file.path(root, "replication.yml"))
  meta <- replicateEverything:::complete_folder_study_meta(meta, root)
  ctx <- list(
    doi = "10.9999/ancestor.test",
    local_root = root,
    is_folder_study = TRUE
  )
  rep <- replicateEverything:::find_replication_entry(meta, "tab_1")

  expect_false(
    replicateEverything:::step_outputs_ready(
      replicateEverything:::find_prep_entry(meta, "analysis_data"),
      ctx,
      meta = meta
    )
  )

  expect_no_error(
    replicateEverything:::ensure_study_ancestor_steps(
      meta,
      rep,
      ctx,
      doi = "10.9999/ancestor.test"
    )
  )
})

test_that("ensure_study_ancestor_steps runs missing parents from steps DAG", {
  root <- tempfile("re_ancestors_")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(file.path(root, "code"), recursive = TRUE)
  dir.create(file.path(root, "outputs", "prep_data"), recursive = TRUE)
  dir.create(file.path(root, "data"), recursive = TRUE)

  writeLines("1,2\n", file.path(root, "data", "raw.csv"))
  writeLines(
    c(
      "prep_step <- function(data) {",
      "  write.csv(data.frame(x = 1), file.path('outputs', 'prep_data', 'out.csv'))",
      "  data.frame(x = 1)",
      "}"
    ),
    file.path(root, "code", "prep_data.R")
  )
  writeLines(
    c(
      "tab_1 <- function(data) {",
      "  if (!file.exists(file.path('outputs', 'prep_data', 'out.csv'))) {",
      "    stop('prep output missing')",
      "  }",
      "  data",
      "}"
    ),
    file.path(root, "code", "tab_1.R")
  )
  yaml <- list(
    paper = list(doi = "10.9999/ancestor.test"),
    steps = list(
      list(
        id = "prep_data",
        type = "transform",
        parents = list(),
        data = "data/raw.csv",
        code = "code/prep_data.R",
        outputs = list("outputs/prep_data/out.csv"),
        engine = "r"
      ),
      list(
        id = "tab_1",
        group = "tab_1",
        type = "table",
        parents = list("prep_data"),
        data = "outputs/prep_data/out.csv",
        code = "code/tab_1.R",
        outputs = list("outputs/tab_1.html"),
        engine = "r"
      )
    )
  )
  yaml::write_yaml(yaml, file.path(root, "replication.yml"))
  replicateEverything::configure_study_folder("10.9999/ancestor.test", root)

  meta <- replicateEverything:::get_replication_meta("10.9999/ancestor.test")
  ctx <- replicateEverything:::paper_context("10.9999/ancestor.test")
  rep <- replicateEverything:::find_replication_entry(meta, "tab_1")

  expect_false(
    replicateEverything:::step_outputs_ready(
      replicateEverything:::find_prep_entry(meta, "prep_data"),
      ctx,
      meta = meta
    )
  )

  replicateEverything:::ensure_study_ancestor_steps(
    meta,
    rep,
    ctx,
    doi = "10.9999/ancestor.test"
  )

  expect_true(file.exists(file.path(root, "outputs", "prep_data", "out.csv")))
})

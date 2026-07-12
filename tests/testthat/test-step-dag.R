test_that("compile_steps_from_legacy builds format child", {
  meta <- list(
    prep = list(
      list(
        id = "prep_a",
        type = "step",
        label = "Prep A",
        output = "outputs/prep_a/data.csv"
      )
    ),
    replications = list(
      list(
        id = "tab_1",
        type = "table",
        label = "Table 1",
        requires = list("prep_a"),
        code = "code/tab_1.R",
        format = "code/format_tab_1.R",
        artifact = "outputs/tab_1.html"
      )
    )
  )
  steps <- compile_steps_from_legacy(meta)
  ids <- vapply(steps, function(x) x$id, character(1))
  expect_true("prep_a" %in% ids)
  expect_true("tab_1" %in% ids)
  expect_true("tab_1_format" %in% ids)
})

test_that("plan_study_run respects given = parents", {
  meta <- list(
    steps = list(
      list(id = "prep_a", type = "transform", label = "Prep A", parents = list()),
      list(
        id = "tab_1",
        type = "table",
        label = "Table 1",
        parents = list("prep_a")
      )
    )
  )
  graph <- study_step_graph(normalize_study_steps(meta))
  plan <- plan_study_run("tab_1", "parents", FALSE, graph)
  expect_equal(plan$given_ids, "prep_a")
  expect_equal(plan$step_ids, "tab_1")
})

test_that("plan_study_run given = nothing includes ancestors", {
  meta <- list(
    steps = list(
      list(id = "prep_a", type = "transform", label = "Prep A", parents = list()),
      list(
        id = "tab_1",
        type = "table",
        label = "Table 1",
        parents = list("prep_a")
      )
    )
  )
  graph <- study_step_graph(normalize_study_steps(meta))
  plan <- plan_study_run("tab_1", "nothing", FALSE, graph)
  expect_equal(plan$step_ids, c("prep_a", "tab_1"))
})

test_that("validate_given_downward_closure rejects gaps", {
  meta <- list(
    steps = list(
      list(id = "a", type = "transform", label = "A", parents = list()),
      list(id = "b", type = "transform", label = "B", parents = list("a")),
      list(id = "c", type = "table", label = "C", parents = list("b"))
    )
  )
  graph <- study_step_graph(normalize_study_steps(meta))
  expect_error(
    plan_study_run("c", c("a", "c"), FALSE, graph),
    "ancestor"
  )
})

test_that("describe_study_dag includes raw data roots", {
  meta <- list(
    steps = list(
      list(
        id = "prep_a",
        type = "transform",
        label = "Prep A",
        parents = list(),
        inputs = list("data/raw/a.csv", "data/raw/b.csv")
      ),
      list(id = "tab_1", type = "table", label = "Table 1", parents = list("prep_a"))
    )
  )
  lines <- describe_study_dag(meta)
  expect_match(lines[[1]], "a\\.csv")
  expect_match(lines[[1]], "Prep A")
  expect_match(lines[[1]], "Table 1")
})

test_that("describe_study_dag renders parallel paths not false linear chain", {
  meta <- list(
    steps = list(
      list(id = "prep_a", type = "transform", label = "Prep A", parents = list()),
      list(id = "tab_1", type = "table", label = "Table 1", parents = list("prep_a")),
      list(id = "tab_2", type = "table", label = "Table 2", parents = list("prep_a")),
      list(
        id = "mid",
        type = "transform",
        label = "Mid",
        parents = list("prep_a")
      ),
      list(id = "fig_1", type = "figure", label = "Figure 1", parents = list("mid"))
    )
  )
  lines <- describe_study_dag(meta)
  expect_length(lines, 1L)
  expect_match(lines[[1]], "Prep A.*Table 1")
  expect_match(lines[[1]], "Prep A.*Table 2")
  expect_match(lines[[1]], "Prep A.*Mid.*Figure 1")
  expect_false(grepl("Table 1.*Table 2", lines[[1]]))
})

test_that("study_dag_for_step returns paths ending at the selected step", {
  meta <- list(
    steps = list(
      list(id = "prep_a", type = "transform", label = "Analysis dataset", parents = list()),
      list(id = "tab_1", type = "table", label = "Table 1", parents = list("prep_a")),
      list(id = "tab_2", type = "table", label = "Table 2", parents = list("prep_a"))
    )
  )
  paths <- study_dag_for_step(meta, "tab_1")
  expect_length(paths, 1L)
  labels <- vapply(paths[[1]], function(n) n$label, character(1))
  expect_equal(tail(labels, 1L), "Table 1")
  expect_true("Analysis dataset" %in% labels)
})


test_that("describe_study_dag renders component chains", {
  meta <- list(
    steps = list(
      list(id = "prep_a", type = "transform", label = "Prep A", parents = list()),
      list(
        id = "tab_1",
        type = "table",
        label = "Table 1",
        parents = list("prep_a")
      ),
      list(id = "fig_2", type = "figure", label = "Figure 2", parents = list())
    )
  )
  lines <- describe_study_dag(meta)
  expect_length(lines, 2L)
  expect_match(lines[[1]], "Prep A")
  expect_match(lines[[1]], "Table 1")
})

test_that("assert_parents_ready errors when parent output missing", {
  skip_if_not(dir.exists(testthat::test_path("fixtures", "rep-10.9999_example")))
  root <- testthat::test_path("fixtures", "rep-10.9999_example")
  meta <- yaml::read_yaml(file.path(root, "replication.yml"))
  meta$steps <- list(
    list(id = "prep_x", type = "transform", label = "Prep", parents = list(),
         outputs = list("outputs/prep_x/missing.dat")),
    list(id = "tab_1", type = "table", label = "T1", parents = list("prep_x"),
         code = "code/tab_1.R", artifact = "outputs/tab_1.html")
  )
  graph <- study_step_graph(normalize_study_steps(meta))
  ctx <- list(local_root = root)
  expect_error(
    assert_parents_ready("tab_1", graph, ctx, meta),
    "Parent step output"
  )
})

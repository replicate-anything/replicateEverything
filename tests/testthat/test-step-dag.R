test_that("normalize_study_steps builds format children from steps block", {
  meta <- list(
    steps = list(
      list(
        id = "prep_a",
        type = "transform",
        label = "Prep A",
        outputs = list("outputs/prep_a/data.csv")
      ),
      list(
        id = "tab_1",
        type = "table",
        label = "Table 1",
        parents = list("prep_a"),
        code = "code/tab_1.R",
        format = "code/format_tab_1.R",
        outputs = list("outputs/tab_1.html")
      ),
      list(
        id = "tab_1_format",
        type = "format",
        parent = "tab_1",
        code = "code/format_tab_1.R"
      )
    )
  )
  steps <- normalize_study_steps(meta)
  ids <- vapply(steps, function(x) x$id, character(1))
  expect_true(all(c("prep_a", "tab_1", "tab_1_format") %in% ids))
})

test_that("plan_study_run respects given = parents", {
  meta <- list(
    steps = list(
      list(id = "prep_a", type = "transform", label = "Prep A"),
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
      list(id = "prep_a", type = "transform", label = "Prep A"),
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
  expect_true("prep_a" %in% plan$step_ids)
  expect_true("tab_1" %in% plan$step_ids)
})

test_that("validate_given_downward_closure rejects incomplete given", {
  meta <- list(
    steps = list(
      list(id = "a", type = "transform"),
      list(id = "b", type = "transform", parents = list("a")),
      list(id = "c", type = "table", parents = list("b"))
    )
  )
  graph <- study_step_graph(normalize_study_steps(meta))
  expect_error(
    validate_given_downward_closure(c("b"), graph),
    "ancestor"
  )
})

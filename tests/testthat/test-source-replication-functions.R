test_that("source_replication_functions skips circular source() chains", {
  tmp <- withr::local_tempdir()
  a <- file.path(tmp, "a.R")
  b <- file.path(tmp, "b.R")
  writeLines(c('source("b.R")', "make_a <- function() 1"), a)
  writeLines(c('source("a.R")', "make_b <- function() 2"), b)

  env <- new.env(parent = globalenv())
  replicateEverything:::source_replication_functions(a, env)
  expect_true(exists("make_a", envir = env, inherits = FALSE))
})

test_that("study_engines_for_plan scopes probes to planned steps", {
  meta <- list(
    paper = list(),
    steps = list(
      list(id = "prep_stata", type = "transform", engine = "stata", parents = list()),
      list(id = "prep_py", type = "transform", engine = "python", parents = list("prep_stata")),
      list(id = "fig_4", type = "figure", engine = "r", parents = list("prep_py"))
    )
  )
  steps <- replicateEverything:::normalize_study_steps(meta)
  graph <- replicateEverything:::study_step_graph(steps)
  plan <- replicateEverything:::plan_study_run("fig_4", c("prep_py", "prep_stata"), FALSE, graph)
  engines <- replicateEverything:::study_engines_for_plan(meta, plan)
  expect_equal(engines, "r")
})

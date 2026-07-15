test_that("script_has_make_call detects footer calls", {
  lines_def_only <- c(
    "make_tab_1 <- function(data) data",
    "helper <- function() 1"
  )
  expect_false(script_has_make_call(lines_def_only, "tab_1"))

  lines_with_call <- c(
    "make_tab_1 <- function(data) data",
    "make_tab_1(readRDS('../outputs/x.rds')) |> format_tab_1()"
  )
  expect_true(script_has_make_call(lines_with_call, "tab_1"))
})

test_that("annotate_replication_code_for_display adds prep notes", {
  rep <- list(
    id = "tab_1",
    type = "table",
    code = "code/tables/tab_1.R",
    parents = list("prep_studies"),
    data = "outputs/prep_studies/studies.rds",
    format = "code/helpers/format_table.R"
  )
  lines <- c(
    'source("../helpers/study_inputs.R")',
    "make_tab_1 <- function(data) data",
    "make_tab_1(readRDS('../outputs/prep_studies/studies.rds'))"
  )
  out <- annotate_replication_code_for_display(lines, rep)
  expect_true(any(grepl("parents: prep_studies", out, fixed = TRUE)))
  expect_true(any(grepl("inputs:", out)))
  expect_true(any(grepl("format_table.R", out, fixed = TRUE)))
})

test_that("check_replication_script_entries fails when make_* is never called", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "code"), recursive = TRUE)
  writeLines(
    "make_tab_1 <- function(data) data",
    file.path(tmp, "code", "tab_1.R")
  )
  meta <- list(
    replications = list(
      list(
        id = "tab_1",
        type = "table",
        engine = "r",
        code = "code/tab_1.R"
      )
    )
  )
  checks <- check_replication_script_entries(tmp, meta)
  expect_false(any(checks$passed[checks$check == "script_entry_tab_1"]))
})

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

test_that("source_replication_functions loads script constants for helpers", {
  tmp <- withr::local_tempdir()
  script <- file.path(tmp, "tab_3.R")
  writeLines(
    c(
      "TAB_3_TREATMENT_TERMS <- c(\"treatmentcore_belief\", \"treatmentdistal_belief\")",
      "extract_lm_robust_benchmarks <- function(models) {",
      "  lapply(TAB_3_TREATMENT_TERMS, function(term) term)",
      "}",
      "make_tab_3 <- function(data) extract_lm_robust_benchmarks(list())"
    ),
    script
  )

  env <- new.env(parent = globalenv())
  replicateEverything:::source_replication_functions(script, env)
  expect_true(exists("TAB_3_TREATMENT_TERMS", envir = env, inherits = FALSE))
  result <- get("make_tab_3", envir = env, inherits = FALSE)()
  expect_equal(result, as.list(get("TAB_3_TREATMENT_TERMS", envir = env, inherits = FALSE)))
})

test_that("source_replication_functions skips data-loading assignments", {
  tmp <- withr::local_tempdir()
  script <- file.path(tmp, "bad.R")
  writeLines(
    c(
      "data <- read.csv(\"study1.csv\")",
      "make_bad <- function() nrow(data)"
    ),
    script
  )

  env <- new.env(parent = globalenv())
  replicateEverything:::source_replication_functions(script, env)
  expect_false(exists("data", envir = env, inherits = FALSE))
  expect_true(exists("make_bad", envir = env, inherits = FALSE))
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

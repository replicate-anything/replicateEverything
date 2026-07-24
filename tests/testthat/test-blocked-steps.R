test_that("step_blocked_reason() returns NULL for a normal step", {
  meta <- list(
    steps = list(
      list(id = "tab_1", type = "table", code = "code/tab_1.R")
    )
  )
  expect_null(step_blocked_reason(meta, "tab_1"))
})

test_that("step_blocked_reason() surfaces the declared blocked_reason", {
  meta <- list(
    steps = list(
      list(
        id = "fig_4",
        type = "figure",
        code = "code/fig_4.do",
        incomplete = TRUE,
        blocked_reason = "Needs policy_details_v3.xlsx, missing from the deposit."
      )
    )
  )
  expect_identical(
    step_blocked_reason(meta, "fig_4"),
    "Needs policy_details_v3.xlsx, missing from the deposit."
  )
})

test_that("step_blocked_reason() falls back to a generic message when incomplete but no reason given", {
  meta <- list(
    steps = list(
      list(id = "fig_9", type = "figure", code = "code/fig_9.do", incomplete = TRUE)
    )
  )
  reason <- step_blocked_reason(meta, "fig_9")
  expect_true(nzchar(reason))
  expect_match(reason, "incomplete")
})

test_that("stop_if_step_blocked() raises 'This object cannot be created because of: <reason>'", {
  meta <- list(
    steps = list(
      list(
        id = "tab_2",
        type = "table",
        code = "code/tab_2.do",
        incomplete = TRUE,
        blocked_reason = "Requires Mathematica, not installed."
      )
    )
  )
  expect_error(
    stop_if_step_blocked(meta, "tab_2"),
    "This object cannot be created because of: Requires Mathematica, not installed\\."
  )
})

test_that("stop_if_step_blocked() is a no-op for a runnable step", {
  meta <- list(
    steps = list(
      list(id = "tab_1", type = "table", code = "code/tab_1.R")
    )
  )
  expect_null(stop_if_step_blocked(meta, "tab_1"))
})

test_that("folder_display_replications() still excludes incomplete steps from baking/audit", {
  meta <- list(
    steps = list(
      list(id = "tab_1", type = "table", code = "code/tab_1.R"),
      list(id = "tab_2", type = "table", code = "code/tab_2.R", incomplete = TRUE,
           blocked_reason = "Missing input file.")
    )
  )
  reps <- folder_display_replications(meta)
  ids <- vapply(reps, function(x) x$id, character(1))
  expect_true("tab_1" %in% ids)
  expect_false("tab_2" %in% ids)
})

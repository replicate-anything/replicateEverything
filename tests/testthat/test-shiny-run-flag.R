test_that("step_shiny_run_enabled defaults to TRUE", {
  expect_true(step_shiny_run_enabled(list(id = "fig_1")))
  expect_true(step_shiny_run_enabled(list(id = "fig_1", shiny_run = TRUE)))
  expect_true(step_shiny_run_enabled(NULL))
})

test_that("step_shiny_run_enabled respects shiny_run: false", {
  expect_false(step_shiny_run_enabled(list(id = "clean_data", shiny_run = FALSE)))
  expect_false(step_shiny_run_enabled(list(id = "clean_data", shiny_run = "false")))
  expect_false(step_shiny_run_enabled(list(id = "clean_data", shiny_run = "no")))
})

test_that("step_shiny_run_message is the fixed short label", {
  expect_identical(
    step_shiny_run_message(list(
      id = "macros",
      shiny_run = FALSE,
      blocked_reason = "Temporarily off in Shiny."
    )),
    "[live run not available on shiny]"
  )
  expect_identical(
    step_shiny_run_message(list(id = "macros", shiny_run = FALSE)),
    "[live run not available on shiny]"
  )
  expect_identical(
    step_shiny_run_message(NULL),
    "[live run not available on shiny]"
  )
})

test_that("shiny_run false is not treated as incomplete / gap", {
  entry <- list(
    id = "compute_mvpf_main",
    label = "Compute MVPF (main)",
    shiny_run = FALSE,
    blocked_reason = "Shiny Live Run off for now.",
    incomplete = FALSE
  )
  expect_null(classify_shiny_run_gap(entry, output_exists = TRUE)$kind)
  expect_true(shiny_step_show_display(
    output_exists = TRUE,
    gap_kind = NULL,
    incomplete = FALSE
  ))
  # Package blocked-reason helper still requires incomplete:
  meta <- list(steps = list(entry))
  expect_null(step_blocked_reason(meta, "compute_mvpf_main"))
})

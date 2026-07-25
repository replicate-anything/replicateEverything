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

test_that("step_required_engine() prefers requires_engine over blocked_reason text", {
  entry <- list(
    id = "fig_1",
    incomplete = TRUE,
    requires_engine = "mathematica",
    blocked_reason = "Needs MATLAB somehow"
  )
  expect_identical(step_required_engine(entry), "Mathematica")
})

test_that("step_required_engine() infers Mathematica from blocked_reason", {
  entry <- list(
    id = "fig_1",
    incomplete = TRUE,
    blocked_reason = "Requires wolframscript (Mathematica)."
  )
  expect_identical(step_required_engine(entry), "Mathematica")
})

test_that("missing_engine_message() uses the two required phrasings", {
  expect_identical(
    missing_engine_message("Figure 1", "Mathematica", "not_available"),
    "Figure 1 not available because of missing Mathematica engine"
  )
  expect_identical(
    missing_engine_message("Figure 1", "Mathematica", "not_reproducible"),
    "Figure 1 not reproducible because of missing Mathematica engine"
  )
})

test_that("step_missing_engine_message() distinguishes absent vs baked", {
  meta <- list(
    steps = list(
      list(
        id = "fig_4",
        type = "figure",
        label = "Figure 4",
        code = "code/fig_4.do",
        incomplete = TRUE,
        requires_engine = "mathematica",
        blocked_reason = "Requires Mathematica."
      )
    )
  )
  expect_identical(
    step_missing_engine_message(meta, "fig_4", output_exists = FALSE),
    "Figure 4 not available because of missing Mathematica engine"
  )
  expect_identical(
    step_missing_engine_message(meta, "fig_4", output_exists = TRUE),
    "Figure 4 not reproducible because of missing Mathematica engine"
  )
})

test_that("stop_if_step_blocked() raises missing-engine phrasing", {
  meta <- list(
    steps = list(
      list(
        id = "tab_2",
        type = "table",
        label = "Table 2",
        code = "code/tab_2.do",
        incomplete = TRUE,
        requires_engine = "mathematica",
        blocked_reason = "Requires Mathematica, not installed."
      )
    )
  )
  expect_error(
    stop_if_step_blocked(meta, "tab_2", output_exists = FALSE),
    "Table 2 not available because of missing Mathematica engine"
  )
  expect_error(
    stop_if_step_blocked(meta, "tab_2", output_exists = TRUE),
    "Table 2 not reproducible because of missing Mathematica engine"
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

test_that("folder_display_replications() still excludes incomplete steps from baking", {
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

test_that("audit records incomplete Mathematica / proprietary steps as skipped jobs", {
  reps <- list(
    list(id = "fig_5", type = "figure", label = "Figure 5", engine = "stata", code = "code/fig_5.do"),
    list(
      id = "fig_1",
      type = "figure",
      label = "Figure 1",
      engine = "stata",
      incomplete = TRUE,
      requires_engine = "mathematica",
      blocked_reason = "Requires Mathematica."
    ),
    list(
      id = "tab_h1",
      type = "table",
      label = "Table H.1",
      engine = "stata",
      incomplete = TRUE,
      data_unavailable = "proprietary",
      blocked_reason = "Proprietary deposit."
    )
  )
  jobs <- audit_jobs_from_replications(reps)
  expect_identical(jobs$what[is.na(jobs$skip_reason)], "fig_5")
  skipped <- jobs[!is.na(jobs$skip_reason), , drop = FALSE]
  expect_setequal(skipped$what, c("fig_1", "tab_h1"))
  expect_true(all(grepl("Mathematica|proprietary", skipped$skip_reason)))
})

test_that("study_required_system_engines() collects Mathematica from incomplete steps", {
  meta <- list(
    steps = list(
      list(id = "fig_5", type = "figure", code = "code/fig_5.do"),
      list(
        id = "compute_mvpf_main",
        type = "transform",
        code = "code/compute_mvpf_main.do",
        incomplete = TRUE,
        requires_engine = "mathematica",
        blocked_reason = "Requires Mathematica."
      ),
      list(
        id = "fig_1",
        type = "figure",
        code = "code/fig_1.do",
        incomplete = TRUE,
        requires_engine = "mathematica",
        blocked_reason = "Requires Mathematica."
      )
    )
  )
  expect_identical(study_required_system_engines(meta), "Mathematica")
})

test_that("format_partial_replication_message() prefers missing-engine phrasing", {
  expect_identical(
    format_partial_replication_message(engines = "Mathematica", incomplete_n = 8L),
    "Only partial replication currently available (missing Mathematica installation)"
  )
  expect_identical(
    format_partial_replication_message(
      engines = c("Mathematica", "MATLAB"),
      incomplete_n = 2L
    ),
    "Only partial replication currently available (missing Mathematica and MATLAB installations)"
  )
  expect_identical(
    format_partial_replication_message(incomplete_n = 3L),
    "Only partial replication currently available (3 outputs marked incomplete)"
  )
  expect_identical(
    format_partial_replication_message(audit_timed_out = 2L),
    "Only partial replication currently available (some audit runs timed out)"
  )
  expect_null(format_partial_replication_message())
})

test_that("study_partial_replication_notice() is driven by yaml incomplete steps", {
  meta <- list(
    steps = list(
      list(id = "fig_5", type = "figure", code = "code/fig_5.do"),
      list(
        id = "fig_1",
        type = "figure",
        label = "Figure 1",
        code = "code/fig_1.do",
        incomplete = TRUE,
        requires_engine = "mathematica",
        blocked_reason = "Requires Mathematica."
      )
    )
  )
  notice <- study_partial_replication_notice(meta, include_registry_audit = FALSE)
  expect_true(notice$partial)
  expect_identical(notice$required_engines, "Mathematica")
  expect_identical(notice$incomplete_ids, "fig_1")
  expect_identical(
    notice$message,
    "Only partial replication currently available (missing Mathematica installation)"
  )

  ok <- study_partial_replication_notice(
    list(steps = list(list(id = "fig_5", type = "figure", code = "code/fig_5.do"))),
    include_registry_audit = FALSE
  )
  expect_false(ok$partial)
  expect_null(ok$message)
})

test_that("data_unavailable proprietary steps get distinct messaging and audit skip", {
  entry <- list(
    id = "tab_h1",
    type = "table",
    label = "Table H.1",
    incomplete = TRUE,
    data_unavailable = "proprietary",
    blocked_reason = "CaixaBank tourist expenditure data not in the public deposit."
  )
  expect_identical(step_data_unavailable(entry), "proprietary")
  expect_identical(
    missing_data_message("Table H.1", "proprietary", "not_available"),
    "Table H.1 not available because of proprietary data"
  )
  meta <- list(steps = list(
    list(id = "tab_1", type = "table", code = "code/tab_1.do"),
    entry
  ))
  expect_identical(
    step_missing_engine_message(meta, "tab_h1", output_exists = FALSE),
    "Table H.1 not available because of proprietary data"
  )
  expect_error(
    stop_if_step_blocked(meta, "tab_h1", output_exists = FALSE),
    "proprietary data"
  )
  notice <- study_partial_replication_notice(meta, include_registry_audit = FALSE)
  expect_true(notice$partial)
  expect_identical(notice$data_unavailable, "proprietary")
  expect_match(notice$message, "proprietary data")
  reps <- folder_display_replications(meta)
  ids <- vapply(reps, function(x) x$id, character(1))
  expect_true("tab_1" %in% ids)
  expect_false("tab_h1" %in% ids)
})

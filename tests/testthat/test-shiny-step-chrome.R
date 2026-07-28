test_that("shiny_step_show_display omits Display for gaps without sinks", {
  expect_true(shiny_step_show_display(output_exists = TRUE, gap_kind = "padlock"))
  expect_true(shiny_step_show_display(output_exists = TRUE, gap_kind = "hammer"))
  expect_false(shiny_step_show_display(output_exists = FALSE, gap_kind = "padlock"))
  expect_false(shiny_step_show_display(output_exists = FALSE, gap_kind = "hammer"))
  expect_false(shiny_step_show_display(
    output_exists = FALSE,
    gap_kind = NULL,
    incomplete = TRUE
  ))
  expect_true(shiny_step_show_display(
    output_exists = FALSE,
    gap_kind = NULL,
    incomplete = FALSE
  ))
})

test_that("shiny_step_show_display does not invert Hahn-style prep chrome", {
  # Available prep without html/png sink (e.g. clean_data / macros / no_lbd):
  # must stay Display-enabled. Engine-gap prep without sink must not.
  available <- list(
    list(id = "clean_data", incomplete = FALSE, gap_kind = NULL, exists = FALSE),
    list(id = "macros", incomplete = FALSE, gap_kind = NULL, exists = FALSE),
    list(id = "compute_mvpf_no_lbd", incomplete = FALSE, gap_kind = NULL, exists = FALSE)
  )
  blocked <- list(
    id = "compute_mvpf_main",
    incomplete = TRUE,
    gap_kind = "hammer",
    exists = FALSE
  )
  for (row in available) {
    # Historical inverted rule (must NOT be used):
    old <- isTRUE(row$exists) || identical(row$gap_kind, "hammer") ||
      identical(row$gap_kind, "padlock")
    expect_false(old)
    expect_true(shiny_step_show_display(
      output_exists = row$exists,
      gap_kind = row$gap_kind,
      incomplete = row$incomplete
    ))
  }
  old_blocked <- isTRUE(blocked$exists) || identical(blocked$gap_kind, "hammer")
  expect_true(old_blocked) # documents the old invert
  expect_false(shiny_step_show_display(
    output_exists = blocked$exists,
    gap_kind = blocked$gap_kind,
    incomplete = blocked$incomplete
  ))

  # Available figure with baked sink stays on; Mathematica fig without sink off.
  expect_true(shiny_step_show_display(
    output_exists = TRUE,
    gap_kind = NULL,
    incomplete = FALSE
  ))
  expect_false(shiny_step_show_display(
    output_exists = FALSE,
    gap_kind = "hammer",
    incomplete = TRUE
  ))
  # Baked Mathematica fig: Display stays (view-only).
  expect_true(shiny_step_show_display(
    output_exists = TRUE,
    gap_kind = "hammer",
    incomplete = TRUE
  ))
})

test_that("shiny_step_long_run_indicator requires sink + audit timeout + no gap", {
  shown <- shiny_step_long_run_indicator(
    output_exists = TRUE,
    audit_timed_out = TRUE,
    gap_kind = NULL,
    incomplete = FALSE,
    timeout_seconds = 600,
    seconds = 600
  )
  expect_true(shown$show)
  expect_match(shown$title, "Long run warning")
  expect_match(shown$title, "time cap")
  expect_match(shown$title, "10 minute")

  expect_false(shiny_step_long_run_indicator(
    output_exists = FALSE,
    audit_timed_out = TRUE
  )$show)

  expect_false(shiny_step_long_run_indicator(
    output_exists = TRUE,
    audit_timed_out = FALSE
  )$show)

  expect_false(shiny_step_long_run_indicator(
    output_exists = TRUE,
    audit_timed_out = TRUE,
    gap_kind = "hammer"
  )$show)

  expect_false(shiny_step_long_run_indicator(
    output_exists = TRUE,
    audit_timed_out = TRUE,
    gap_kind = "padlock"
  )$show)

  expect_false(shiny_step_long_run_indicator(
    output_exists = TRUE,
    audit_timed_out = TRUE,
    incomplete = TRUE
  )$show)
})

test_that("format_long_run_warning uses timeout_seconds when available", {
  msg <- format_long_run_warning(timeout_seconds = 90, seconds = 90)
  expect_match(msg, "Long run warning")
  expect_match(msg, "2 minute")
  expect_match(msg, "precomputed")

  short <- format_long_run_warning(timeout_seconds = 20)
  expect_match(short, "20 seconds")

  fallback <- format_long_run_warning()
  expect_match(fallback, "configured audit time limit")
})

test_that("lookup_replication_audit_runtime surfaces timeout_seconds", {
  root <- tempfile("audit-timeout-chrome-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  results <- data.frame(
    doi = "10.9999/timeout-example",
    title = "Example",
    object = "fig_slow",
    object_label = "Figure slow",
    type = "figure",
    engine = "r",
    success = FALSE,
    run_ok = FALSE,
    substantive_ok = NA,
    seconds = 120,
    runtime_category = "medium",
    timed_out = TRUE,
    timeout_seconds = 120,
    error_snippet = "Timed out after 120 seconds",
    stringsAsFactors = FALSE
  )
  audit <- structure(
    list(
      patience = 120,
      started_at = Sys.time(),
      finished_at = Sys.time(),
      results = results,
      summary = list(studies = 1L, runs = 1L, success = 0L, failed = 0L, timed_out = 1L)
    ),
    class = "audit_everything"
  )
  saveRDS(audit, file.path(root, "audit_latest.rds"))

  if (exists(".registry_audit_cache", envir = asNamespace("replicateEverything"), inherits = FALSE)) {
    cache <- get(".registry_audit_cache", envir = asNamespace("replicateEverything"))
    rm(list = ls(envir = cache), envir = cache)
  }

  hit <- lookup_replication_audit_runtime(
    "10.9999/timeout-example",
    "fig_slow",
    engine = "r",
    registry_root = root
  )
  expect_true(hit$available)
  expect_true(hit$timed_out)
  expect_equal(hit$timeout_seconds, 120)
  expect_identical(hit$runtime_category, "slow")

  ind <- shiny_step_long_run_indicator(
    output_exists = TRUE,
    audit_timed_out = hit$timed_out,
    timeout_seconds = hit$timeout_seconds,
    seconds = hit$seconds
  )
  expect_true(ind$show)
  expect_match(ind$title, "2 minute")
})

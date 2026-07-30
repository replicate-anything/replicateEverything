test_that("shiny_runtime_estimate_seconds prefers bake after timeout", {
  expect_equal(
    shiny_runtime_estimate_seconds(list(
      timed_out = TRUE,
      bake_seconds = 120,
      seconds = 20,
      timeout_seconds = 20
    )),
    120
  )
  expect_equal(
    shiny_runtime_estimate_seconds(list(
      timed_out = FALSE,
      bake_seconds = 30,
      seconds = 90,
      timeout_seconds = 60
    )),
    90
  )
  expect_true(is.na(shiny_runtime_estimate_seconds(NULL)))
})

test_that("format_run_duration_short covers second/minute/hour bands", {
  expect_match(format_run_duration_short(45), "seconds")
  expect_match(format_run_duration_short(120), "minute")
  expect_match(format_run_duration_short(7200), "hours")
})

test_that("format_live_run_estimate_gate distinguishes WZB block vs local warn", {
  block <- format_live_run_estimate_gate(900, 600, block = TRUE)
  warn <- format_live_run_estimate_gate(900, 600, block = FALSE)
  expect_match(block, "WZB Shiny live-run limit", fixed = TRUE)
  expect_match(block, "please run it locally", fixed = TRUE)
  expect_match(warn, "Long run warning", fixed = TRUE)
  expect_match(warn, "will continue", fixed = TRUE)
  expect_false(grepl("WZB", warn, fixed = TRUE))
})

test_that("shiny_display_action short-circuits when chrome says unavailable", {
  local_mocked_bindings(
    shiny_step_display_chrome = function(...) {
      list(
        displayable = FALSE,
        output_exists = FALSE,
        gap = list(kind = "padlock", message = "proprietary data unavailable"),
        incomplete = TRUE,
        entry = list(id = "fig_x"),
        message = "proprietary data unavailable"
      )
    },
    load_replication_for_display = function(...) {
      stop("should not load artifact when Display is greyed")
    },
    .package = "replicateEverything"
  )
  out <- shiny_display_action("10.0/example", "fig_x")
  expect_false(out$ok)
  expect_true(out$missing)
  expect_true(out$unavailable)
  expect_equal(out$source, "artifact")
  expect_match(out$message, "proprietary data unavailable", fixed = TRUE)
})

test_that("shiny_display_action loads artifact when displayable", {
  local_mocked_bindings(
    shiny_step_display_chrome = function(...) {
      list(
        displayable = TRUE,
        output_exists = TRUE,
        gap = list(kind = NULL),
        incomplete = FALSE,
        entry = list(id = "tab_1"),
        message = ""
      )
    },
    load_replication_for_display = function(...) {
      list(ok = TRUE, value = "<table></table>", raw = "<table></table>", source = "artifact")
    },
    resolve_replication_display = function(...) {
      list(ok = TRUE, value = "<table></table>")
    },
    .package = "replicateEverything"
  )
  out <- shiny_display_action("10.0/example", "tab_1")
  expect_true(out$ok)
  expect_equal(out$source, "artifact")
  expect_equal(out$value, "<table></table>")
})

test_that("shiny_run_action skips shiny_run: false without live execute", {
  local_mocked_bindings(
    get_replication_meta = function(...) list(paper = list(doi = "10.0/example")),
    find_replication_entry = function(...) {
      list(id = "heavy", shiny_run = FALSE)
    },
    load_replication_for_display = function(...) {
      stop("should not live-run when shiny_run is false")
    },
    .package = "replicateEverything"
  )
  out <- shiny_run_action(
    "10.0/example",
    "heavy",
    check_compatibility = FALSE,
    on_wzb = FALSE,
    execute = TRUE
  )
  expect_false(out$ok)
  expect_false(out$ok_to_execute)
  expect_true(out$skipped)
  expect_equal(out$gate, "shiny_run")
  expect_match(out$message, "live run not available", fixed = TRUE)
})

test_that("shiny_run_action hard-blocks long estimates on WZB and soft-warns locally", {
  chrome <- list(
    displayable = TRUE,
    output_exists = TRUE,
    gap = list(kind = NULL),
    incomplete = FALSE,
    entry = list(id = "slow"),
    message = ""
  )
  local_mocked_bindings(
    get_replication_meta = function(...) list(paper = list(doi = "10.0/example")),
    find_replication_entry = function(...) list(id = "slow", shiny_run = TRUE),
    shiny_step_display_chrome = function(...) chrome,
    check_study_compatibility = function(...) {
      list(ready = TRUE, message = "", error = NULL)
    },
    lookup_replication_audit_runtime = function(...) {
      list(
        available = TRUE,
        timed_out = TRUE,
        bake_seconds = 900,
        seconds = 20,
        timeout_seconds = 20,
        advice = ""
      )
    },
    load_replication_for_display = function(...) {
      list(ok = TRUE, value = "ok", raw = "ok", source = "live")
    },
    resolve_replication_display = function(...) {
      list(ok = TRUE, value = "ok")
    },
    .package = "replicateEverything"
  )

  wzb <- shiny_run_action(
    "10.0/example",
    "slow",
    on_wzb = TRUE,
    estimate_limit_seconds = 600,
    check_compatibility = TRUE,
    execute = FALSE
  )
  expect_false(wzb$ok_to_execute)
  expect_true(wzb$estimate_blocked)
  expect_equal(wzb$gate, "estimate")
  expect_match(wzb$message, "WZB", fixed = TRUE)

  local <- shiny_run_action(
    "10.0/example",
    "slow",
    on_wzb = FALSE,
    estimate_limit_seconds = 600,
    check_compatibility = TRUE,
    execute = TRUE
  )
  expect_true(local$ok)
  expect_true(local$ok_to_execute)
  expect_false(local$estimate_blocked)
  expect_match(local$long_run_warning, "Long run warning", fixed = TRUE)
})

test_that("shiny_run_action uses compatibility message field when not ready", {
  local_mocked_bindings(
    get_replication_meta = function(...) list(paper = list(doi = "10.0/example")),
    find_replication_entry = function(...) list(id = "tab_1", shiny_run = TRUE),
    shiny_step_display_chrome = function(...) {
      list(
        displayable = TRUE,
        output_exists = TRUE,
        gap = list(kind = NULL),
        incomplete = FALSE,
        entry = list(id = "tab_1"),
        message = ""
      )
    },
    check_study_compatibility = function(...) {
      list(
        ready = FALSE,
        message = "PACKAGE HINT: missing foo",
        error = "PACKAGE HINT: missing foo"
      )
    },
    load_replication_for_display = function(...) {
      stop("should not live-run when compat fails")
    },
    .package = "replicateEverything"
  )
  out <- shiny_run_action(
    "10.0/example",
    "tab_1",
    on_wzb = FALSE,
    check_compatibility = TRUE,
    execute = TRUE
  )
  expect_false(out$ok)
  expect_equal(out$gate, "compat")
  expect_match(out$message, "PACKAGE HINT: missing foo", fixed = TRUE)
})

test_that("check_study_compatibility attaches message/error when not ready", {
  skip_if_not(
    exists("with_fixture_opts", mode = "function"),
    "fixture helpers unavailable"
  )
  with_fixture_opts({
    audit <- check_study_compatibility(fixture_doi(), materialize_study = FALSE)
    expect_s3_class(audit, "study_system_compatibility")
    expect_true("message" %in% names(audit))
    if (isTRUE(audit$ready)) {
      expect_equal(audit$message, "")
      expect_null(audit$error)
    } else {
      expect_true(nzchar(audit$message))
      expect_identical(audit$error, audit$message)
    }
  })
})

test_that("classify_shiny_run_gap prefers padlock for data_unavailable", {
  gap <- classify_shiny_run_gap(
    list(
      id = "tab_h1",
      label = "Table H.1",
      incomplete = TRUE,
      data_unavailable = "proprietary",
      requires_engine = "mathematica"
    ),
    output_exists = FALSE
  )
  expect_identical(gap$kind, "padlock")
  expect_match(gap$message, "proprietary data")
  expect_null(gap$engine)
})

test_that("classify_shiny_run_gap uses hammer for missing-engine yaml gaps", {
  absent <- classify_shiny_run_gap(
    list(
      id = "fig_1",
      label = "Figure 1",
      incomplete = TRUE,
      requires_engine = "mathematica"
    ),
    output_exists = FALSE
  )
  expect_identical(absent$kind, "hammer")
  expect_identical(absent$mode, "not_available")
  expect_identical(
    absent$message,
    "Figure 1 not available because of missing Mathematica engine"
  )

  baked <- classify_shiny_run_gap(
    list(
      id = "fig_1",
      label = "Figure 1",
      incomplete = TRUE,
      requires_engine = "mathematica"
    ),
    output_exists = TRUE
  )
  expect_identical(baked$kind, "hammer")
  expect_identical(baked$mode, "not_reproducible")
  expect_identical(
    baked$message,
    "Figure 1 not reproducible because of missing Mathematica engine"
  )
})

test_that("classify_shiny_run_gap hammers when live engine probe fails on baked output", {
  gap <- classify_shiny_run_gap(
    list(
      id = "fig_1",
      label = "Figure 1",
      incomplete = FALSE,
      requires_engine = "mathematica"
    ),
    output_exists = TRUE,
    engine_available = FALSE
  )
  expect_identical(gap$kind, "hammer")
  expect_identical(gap$mode, "not_reproducible")
})

test_that("classify_shiny_run_gap uses audit skip for bake-gap hammer", {
  gap <- classify_shiny_run_gap(
    list(id = "fig_1", label = "Figure 1", incomplete = FALSE),
    output_exists = FALSE,
    audit_skipped_engine = TRUE
  )
  expect_identical(gap$kind, "hammer")
})

test_that("study_gap_flags_from_entries separates padlock and hammer studies", {
  flags <- study_gap_flags_from_entries(list(
    list(id = "tab_1", type = "table", code = "code/tab_1.do"),
    list(
      id = "tab_h1",
      incomplete = TRUE,
      data_unavailable = "proprietary",
      label = "Table H.1"
    ),
    list(
      id = "fig_1",
      incomplete = TRUE,
      requires_engine = "mathematica",
      label = "Figure 1"
    )
  ))
  expect_true(flags$data_unavailable)
  expect_true(flags$missing_engine)
})

test_that("audit_reason_is_missing_engine detects phrasing", {
  expect_true(audit_reason_is_missing_engine(
    "Figure 1 not available because of missing Mathematica engine"
  ))
  expect_false(audit_reason_is_missing_engine(
    "Table H.1 not available because of proprietary data"
  ))
})

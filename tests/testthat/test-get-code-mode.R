test_that("get_code emits R figure usage tip with yaml-implied call", {
  with_fixture_opts({
    msgs <- character(0)
    withCallingHandlers(
      {
        invisible(get_code(fixture_doi(), "fig_1", mode = "definitions"))
      },
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    tip <- paste(msgs, collapse = "\n")
    expect_true(grepl("R function definitions", tip, fixed = TRUE))
    expect_true(grepl("figure", tip, fixed = TRUE))
    expect_true(grepl("run_replication", tip, fixed = TRUE))
    expect_true(grepl("mode = \"run\"", tip, fixed = TRUE))
    expect_true(grepl("yaml-implied", tip, fixed = TRUE))
    expect_true(grepl("make_fig_1|generate_figure", tip))
  })
})

test_that("get_code emits R table usage tip", {
  with_fixture_opts({
    msgs <- character(0)
    withCallingHandlers(
      {
        invisible(get_code(fixture_doi(), "tab_1", mode = "definitions"))
      },
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    tip <- paste(msgs, collapse = "\n")
    expect_true(grepl("R function definitions", tip, fixed = TRUE))
    expect_true(grepl("table", tip, fixed = TRUE))
    expect_true(grepl("run_replication", tip, fixed = TRUE))
    expect_true(grepl("yaml-implied", tip, fixed = TRUE))
  })
})

test_that("get_code emits Stata usage tip for stata fixture", {
  with_fixture_stata_opts({
    msgs <- character(0)
    withCallingHandlers(
      {
        invisible(get_code(fixture_stata_doi(), "tab_1"))
      },
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    tip <- paste(msgs, collapse = "\n")
    expect_true(grepl("Stata script text", tip, fixed = TRUE))
    expect_true(grepl("not R", tip, fixed = TRUE))
    expect_true(grepl("run_replication", tip, fixed = TRUE))
    expect_true(grepl("do \"", tip, fixed = TRUE))
    expect_true(grepl("eval\\(parse", tip))
    expect_false(grepl("mode = \"run\"", tip, fixed = TRUE))
  })
})

test_that("emit_get_code_usage_message is engine- and type-aware", {
  msgs <- character(0)
  withCallingHandlers(
    {
      emit_get_code_usage_message(engine = "r", type = "transform")
      emit_get_code_usage_message(engine = "python", type = "figure")
    },
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_true(grepl("R function definitions", msgs[[1]], fixed = TRUE))
  expect_true(grepl("step", msgs[[1]], fixed = TRUE))
  expect_true(grepl("Python script text", msgs[[2]], fixed = TRUE))
  expect_true(grepl("figure", msgs[[2]], fixed = TRUE))
  expect_true(grepl("eval\\(parse", msgs[[2]]))
})

test_that("get_code quiet option suppresses usage tip", {
  with_fixture_opts({
    msgs <- character(0)
    withCallingHandlers(
      {
        withr::with_options(
          list(replicateEverything.quiet_get_code = TRUE),
          invisible(get_code(fixture_doi(), "fig_1"))
        )
      },
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    expect_false(any(grepl("run_replication", msgs, fixed = TRUE)))
  })
})

test_that("get_code mode=run appends yaml-implied call for fixture", {
  with_fixture_opts({
    withr::with_options(
      list(replicateEverything.quiet_get_code = TRUE),
      {
        def <- get_code(fixture_doi(), "tab_1", mode = "definitions")
        run <- get_code(fixture_doi(), "tab_1", mode = "run")
      }
    )
    expect_false(any(grepl("run \\(from replication\\.yml", def)))
    expect_true(any(grepl("run \\(from replication\\.yml", run)))
    expect_true(any(grepl("generate_table\\(data\\)", run)))
    expect_true(any(grepl("data/example\\.csv", run)))
  })
})

test_that("get_code mode=run uses yaml recipe even when nframe footer present", {
  lines <- c(
    "make_tab_1 <- function(data) data",
    "format_tab_1 <- function(object) object",
    "# Run the code below to manually create outputs using functions defined above.",
    "if (sys.nframe() == 0L) {",
    "  make_tab_1(data.frame(x = 1)) |> format_tab_1()",
    "}"
  )
  rep <- list(
    id = "tab_1",
    type = "table",
    data = "data/x.csv",
    format = "format_tab_1"
  )
  out <- prepare_get_code_for_run(lines, rep)
  expect_true(any(grepl("sys\\.nframe", out)))
  expect_true(any(grepl("run \\(from replication\\.yml", out)))
  expect_true(any(grepl("utils::read.csv\\(\"data/x.csv\"", out)))
  expect_true(any(grepl("make_tab_1\\(data\\) \\|> format_tab_1\\(\\)", out)))
  expect_false(any(grepl("if \\(TRUE\\)", out)))
})

test_that("ungate_nframe_footer preserves body (legacy helper)", {
  lines <- c(
    "if (sys.nframe() == 0) {",
    "  make_fig_1()",
    "}"
  )
  out <- ungate_nframe_footer(lines)
  expect_equal(out[[1]], "if (TRUE) {")
  expect_equal(out[[2]], "  make_fig_1()")
})

test_that("yaml_implied_call_lines builds load -> make -> format", {
  rep <- list(
    id = "tab_1",
    data = "data/a.csv",
    format = "format_tab_1"
  )
  lines <- yaml_implied_call_lines(rep)
  expect_equal(
    lines,
    c(
      'data <- utils::read.csv("data/a.csv", stringsAsFactors = FALSE)',
      "make_tab_1(data) |> format_tab_1()"
    )
  )
})

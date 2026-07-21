test_that("get_code emits usage tip for any mode", {
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
    expect_true(any(grepl("run_replication", msgs, fixed = TRUE)))
    expect_true(any(grepl("mode = \"run\"", msgs, fixed = TRUE)))
  })
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

test_that("get_code mode=run ungates nframe footer", {
  lines <- c(
    "make_tab_1 <- function(data) data",
    "format_tab_1 <- function(object) object",
    "# Run the code below to manually create outputs using functions defined above.",
    "if (sys.nframe() == 0L) {",
    "  make_tab_1(data.frame(x = 1)) |> format_tab_1()",
    "}"
  )
  rep <- list(id = "tab_1", type = "table", data = "data/x.csv")
  out <- prepare_get_code_for_run(lines, rep)
  expect_true(any(grepl("if \\(TRUE\\)", out)))
  expect_false(any(grepl("sys\\.nframe", out)))
  expect_false(any(grepl("run \\(from replication\\.yml", out)))
})

test_that("ungate_nframe_footer preserves body", {
  lines <- c(
    "if (sys.nframe() == 0) {",
    "  make_fig_1()",
    "}"
  )
  out <- ungate_nframe_footer(lines)
  expect_equal(out[[1]], "if (TRUE) {")
  expect_equal(out[[2]], "  make_fig_1()")
})

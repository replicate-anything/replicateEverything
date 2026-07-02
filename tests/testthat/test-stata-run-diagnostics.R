test_that("stata_run_dir is under study artifacts staging", {
  run_dir <- stata_run_dir("/tmp/study", "/tmp/study/artifacts/staging")
  expect_equal(run_dir, "/tmp/study/artifacts/staging/.run")
})

test_that("stata_batch_args uses platform-specific invocation", {
  if (.Platform$OS.type == "windows") {
    expect_equal(stata_batch_args("/tmp/runner.do"), c("/e", "do", "/tmp/runner.do"))
  } else {
    expect_equal(stata_batch_args("/tmp/runner.do"), c("-b", "/tmp/runner.do"))
  }
})

test_that("stata_run_failed_message reports whether Stata ran", {
  run <- list(
    ran = TRUE,
    stata_executable = "/usr/bin/stata-mp",
    exit_status = 1L,
    do_path = "/tmp/code/tab_1.do",
    workdir = "/tmp/study",
    staging_dir = "/tmp/staging/rep-study",
    log_path = "/tmp/replicate_tab_1.log",
    log_exists = TRUE,
    stata_error = "r(601);",
    log_tail = "last line"
  )
  msg <- stata_run_failed_message(run)
  expect_match(msg, "Stata ran: yes")
  expect_match(msg, "Exit status: 1")
  expect_match(msg, "Log exists: yes")
  expect_match(msg, "Log tail:")
})

test_that("stata_output_missing_message lists staging directories", {
  run <- list(
    ran = TRUE,
    stata_executable = "/usr/bin/stata-mp",
    exit_status = 0L,
    do_path = "/tmp/code/tab_1.do",
    workdir = "/tmp/study",
    staging_dir = "/tmp/staging/rep-study",
    log_path = "/tmp/replicate_tab_1.log",
    log_exists = TRUE,
    stata_error = NULL,
    log_tail = "end of log"
  )
  msg <- stata_output_missing_message(
    "/tmp/study/artifacts/staging/Table1.smcl",
    "/tmp/study",
    run,
    staging_dir = "/tmp/staging/rep-study"
  )
  expect_match(msg, "Stata ran: yes")
  expect_match(msg, "Expected file:")
  expect_match(msg, "Writable staging")
})

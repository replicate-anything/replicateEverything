test_that("stata_batch_log_name derives runner log basename", {
  expect_equal(
    stata_batch_log_name("/tmp/study/artifacts/staging/.run/replicate_tab_1.do"),
    "replicate_tab_1.log"
  )
})

test_that("cleanup_stata_stray_batch_logs removes logs outside run dir", {
  tmp <- tempfile("stata_stray_")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  run_dir <- file.path(tmp, "artifacts", "staging", ".run")
  dir.create(run_dir, recursive = TRUE)
  keep <- file.path(run_dir, "replicate_tab_1.log")
  writeLines("keep", keep)
  stray <- file.path(tmp, "replicate_tab_1.log")
  writeLines("stray", stray)
  cleanup_stata_stray_batch_logs(tmp, "replicate_tab_1.log", keep = keep)
  expect_false(file.exists(stray))
  expect_true(file.exists(keep))
})

test_that("stata_run_dir uses ephemeral temp directory", {
  run_dir <- stata_run_dir("/tmp/study", "/tmp/study/artifacts/staging")
  expect_match(run_dir, "replicateEverything-stata")
  expect_true(grepl("/\\.run$", run_dir))
  expect_true(dir.exists(run_dir))
  cleanup_stata_run_dir(run_dir)
  expect_false(dir.exists(run_dir))
})

test_that("stata_shell_do_path shortens spaced paths on Windows", {
  skip_if_not(.Platform$OS.type == "windows")
  tmp <- tempfile("stata path test")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  do_file <- file.path(tmp, "tab_1.do")
  writeLines("version 17", do_file)
  path <- stata_shell_do_path(do_file)
  expect_true(file.exists(path))
})

test_that("stata_batch_args uses platform-specific invocation", {
  runner <- "/tmp/runner.do"
  if (.Platform$OS.type == "windows") {
    expect_equal(
      stata_batch_args(runner),
      c("/e", "do", stata_shell_do_path(runner))
    )
  } else {
    expect_equal(stata_batch_args(runner), c("-b", runner))
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

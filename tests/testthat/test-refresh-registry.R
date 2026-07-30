test_that("refresh_registry light path rebuilds index and summary without live audit", {
  registry_root <- file.path(testthat::test_path(".."), "fixtures", "registry")
  testthat::skip_if_not(dir.exists(registry_root), "fixture registry missing")

  tmp <- withr::local_tempdir()
  reg <- file.path(tmp, "registry")
  dir.create(file.path(reg, "studies"), recursive = TRUE)
  file.copy(
    file.path(registry_root, "studies", "10.9999_example.yml"),
    file.path(reg, "studies", "10.9999_example.yml")
  )
  stub <- yaml::read_yaml(file.path(reg, "studies", "10.9999_example.yml"))
  stub$maintainer <- list(name = "Test Maintainer", email = "test@example.org")
  stub$collections <- list("APSR")
  stub$languages <- list("r")
  yaml::write_yaml(stub, file.path(reg, "studies", "10.9999_example.yml"))

  audit_called <- FALSE
  local_mocked_bindings(
    audit_everything = function(...) {
      audit_called <<- TRUE
      stop("audit_everything should not run when audit = FALSE")
    },
    .package = "replicateEverything"
  )

  out <- suppressMessages(refresh_registry(
    registry_root = reg,
    audit = FALSE,
    verbose = FALSE
  ))

  expect_false(audit_called)
  expect_true(file.exists(file.path(reg, "index.csv")))
  expect_true(file.exists(file.path(reg, "shiny_studies.json")))
  expect_true(file.exists(file.path(reg, "audit_summary.json")))
  expect_null(out$audit)
  expect_equal(out$index$n, 1L)
})

test_that("refresh_registry audit = TRUE passes through to audit_everything", {
  registry_root <- file.path(testthat::test_path(".."), "fixtures", "registry")
  testthat::skip_if_not(dir.exists(registry_root), "fixture registry missing")

  tmp <- withr::local_tempdir()
  reg <- file.path(tmp, "registry")
  dir.create(file.path(reg, "studies"), recursive = TRUE)
  file.copy(
    file.path(registry_root, "studies", "10.9999_example.yml"),
    file.path(reg, "studies", "10.9999_example.yml")
  )
  stub <- yaml::read_yaml(file.path(reg, "studies", "10.9999_example.yml"))
  stub$maintainer <- list(name = "Test Maintainer", email = "test@example.org")
  stub$collections <- list("APSR")
  stub$languages <- list("r")
  yaml::write_yaml(stub, file.path(reg, "studies", "10.9999_example.yml"))

  captured <- NULL
  local_mocked_bindings(
    audit_everything = function(...) {
      captured <<- list(...)
      structure(
        list(results = data.frame(), summary = list(runs = 0L)),
        class = "audit_everything"
      )
    },
    .package = "replicateEverything"
  )

  out <- suppressMessages(refresh_registry(
    registry_root = reg,
    audit = TRUE,
    patience = 11,
    verbose = FALSE,
    seed = FALSE
  ))

  expect_false(is.null(captured))
  expect_equal(captured$patience, 11)
  expect_null(captured$dois)
  expect_s3_class(out$audit, "audit_everything")
})

test_that("refresh_registry audit = dois character passes dois through", {
  registry_root <- file.path(testthat::test_path(".."), "fixtures", "registry")
  testthat::skip_if_not(dir.exists(registry_root), "fixture registry missing")

  tmp <- withr::local_tempdir()
  reg <- file.path(tmp, "registry")
  dir.create(file.path(reg, "studies"), recursive = TRUE)
  file.copy(
    file.path(registry_root, "studies", "10.9999_example.yml"),
    file.path(reg, "studies", "10.9999_example.yml")
  )
  stub <- yaml::read_yaml(file.path(reg, "studies", "10.9999_example.yml"))
  stub$maintainer <- list(name = "Test Maintainer", email = "test@example.org")
  stub$collections <- list("APSR")
  stub$languages <- list("r")
  yaml::write_yaml(stub, file.path(reg, "studies", "10.9999_example.yml"))

  captured <- NULL
  local_mocked_bindings(
    audit_everything = function(...) {
      captured <<- list(...)
      structure(
        list(results = data.frame(), summary = list(runs = 0L)),
        class = "audit_everything"
      )
    },
    .package = "replicateEverything"
  )

  suppressMessages(refresh_registry(
    registry_root = reg,
    audit = c("10.9999/example", "  "),
    verbose = FALSE,
    seed = FALSE
  ))

  expect_equal(captured$dois, "10.9999/example")
})

test_that("audit_report is read-only and summarizes health buckets", {
  root <- tempfile("audit-report-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  jobs <- data.frame(
    doi = c("10.1/a", "10.1/b"),
    title = c("Study A", "Study B"),
    object = c("fig_1", "tab_1"),
    engine = c("r", "r"),
    success = c(TRUE, FALSE),
    timed_out = c(FALSE, TRUE),
    skipped = c(FALSE, FALSE),
    substantive_ok = c(NA, NA),
    error_snippet = c("", "Timed out"),
    progress_category = c("replicating", "timed_out"),
    stringsAsFactors = FALSE
  )
  replicateEverything:::write_registry_audit_jobs(jobs, registry_root = root)
  replicateEverything:::refresh_registry_audit_summary(registry_root = root)

  mtime_before <- file.info(file.path(root, "audit_jobs.csv"))$mtime
  rep <- audit_report(registry_root = root, by_study = TRUE)
  mtime_after <- file.info(file.path(root, "audit_jobs.csv"))$mtime

  expect_s3_class(rep, "audit_report")
  expect_equal(as.integer(rep$progress[["replicating"]]), 1L)
  expect_equal(as.integer(rep$progress[["timed_out"]]), 1L)
  expect_true(is.data.frame(rep$by_study))
  expect_equal(nrow(rep$by_study), 2L)
  expect_equal(mtime_before, mtime_after)
})

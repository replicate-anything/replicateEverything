test_that("maintainer_dependency_hint mentions install functions", {
  hint <- maintainer_dependency_hint("10.1017/S0003055426101749")
  expect_type(hint, "character")
  expect_match(hint, "install_study_dependencies")
  expect_match(hint, "install_registry_dependencies")
  expect_match(hint, "check_study_compatibility")
  expect_match(hint, "Renviron")
})

test_that("check_study_compatibility wraps study audit", {
  with_fixture_stata_opts({
    audit <- check_study_compatibility(fixture_stata_doi(), materialize_study = TRUE)
    expect_s3_class(audit, "study_system_compatibility")
    expect_equal(audit$languages, "stata")
  })
})

test_that("assert_study_ready_for_replication stops with hint when R deps missing", {
  meta <- list(
    paper = list(dependencies = list("__not_a_real_pkg_xyz__")),
    replications = list(list(id = "tab_1", engine = "r", type = "table")),
    languages = "r"
  )
  expect_error(
    replicateEverything:::assert_study_ready_for_replication(
      "10.9999/test",
      meta = meta,
      install_deps = FALSE
    ),
    "install_study_dependencies"
  )
})

test_that("find_stata_executable respects STATA env var", {
  fake <- tempfile(fileext = ".exe")
  on.exit(unlink(fake), add = TRUE)
  writeLines("stub", fake)
  old <- Sys.getenv("STATA", unset = NA)
  on.exit({
    if (is.na(old)) Sys.unsetenv("STATA") else Sys.setenv(STATA = old)
  }, add = TRUE)
  Sys.setenv(STATA = fake)
  expect_equal(
    replicateEverything:::find_stata_executable(),
    normalizePath(fake, winslash = "/", mustWork = FALSE)
  )
})

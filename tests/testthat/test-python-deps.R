test_that("python_missing_dependencies uses importlib find_spec", {
  python <- Sys.which("python")
  skip_if(!nzchar(python), "python not on PATH")
  missing <- replicateEverything:::python_missing_dependencies(
    python,
    c("sys", "__not_a_real_pkg_xyz__")
  )
  skip_if("sys" %in% missing, "python probe could not import stdlib sys")
  expect_false("sys" %in% missing)
  expect_true("__not_a_real_pkg_xyz__" %in% missing)
})

test_that("python_dep_import_name maps imbalanced-learn to imblearn", {
  expect_equal(
    replicateEverything:::python_dep_import_name("imbalanced-learn"),
    "imblearn"
  )
})

test_that("verify_stata_dependencies does not run install scripts by default", {
  study <- tempfile("stata-verify-")
  dir.create(study, recursive = TRUE)
  dir.create(file.path(study, "code", "helpers"), recursive = TRUE)
  on.exit(unlink(study, recursive = TRUE), add = TRUE)
  writeLines("version 17\nexit 0", file.path(study, "code", "helpers", "probe_stata_deps.do"))
  writeLines(
    c("version 17", "display as error INSTALL_SHOULD_NOT_RUN", "exit 9"),
    file.path(study, "code", "helpers", "install_stata_deps.do")
  )
  meta <- list(
    stata_deps_probe = "code/helpers/probe_stata_deps.do",
    stata_dependencies = list("code/helpers/install_stata_deps.do")
  )
  skip_if(is.null(replicateEverything:::find_stata_executable()), "Stata not installed")
  withr::local_options(list(replicateEverything.install_stata_deps = FALSE))
  expect_message(
    replicateEverything:::verify_stata_dependencies(study, meta = meta),
    "Checking Stata dependencies"
  )
})

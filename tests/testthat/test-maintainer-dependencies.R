test_that("resolve_index_study_location falls back when doi is blank", {
  row <- data.frame(
    folder = "rep-10.1017-S0003055403000534--alt-1",
    handle = "rep-10.1017-S0003055403000534--alt-1",
    doi = "",
    stringsAsFactors = FALSE
  )
  expect_equal(
    replicateEverything:::resolve_index_study_location(row),
    "rep-10.1017-S0003055403000534--alt-1"
  )
})

test_that("resolve_index_study_location works for one-row tibble slices", {
  skip_if_not_installed("tibble")
  idx <- tibble::tibble(
    folder = "10.1017S0003055403000534",
    handle = "10.1017S0003055403000534",
    doi = "10.1017/s0003055403000534",
    repo = "replicate-anything/rep-10.1017-S0003055403000534"
  )
  row <- idx[1, , drop = FALSE]
  expect_equal(
    replicateEverything:::resolve_index_study_location(row),
    "10.1017/s0003055403000534"
  )
})

test_that("install_registry_dependencies does not treat blank index doi as local cwd", {
  row <- data.frame(
    folder = "rep-10.1017-S0003055403000534--alt-1",
    handle = "rep-10.1017-S0003055403000534--alt-1",
    doi = "",
    repo = "replicate-anything/rep-10.1017-S0003055403000534--alt-1",
    stringsAsFactors = FALSE
  )
  idx <- rbind(
    data.frame(
      folder = "10.1017S0003055403000534",
      handle = "10.1017S0003055403000534",
      doi = "10.1017/s0003055403000534",
      repo = "replicate-anything/rep-10.1017-S0003055403000534",
      stringsAsFactors = FALSE
    ),
    row
  )
  install_calls <- list()
  stub_load_index <- function() idx
  stub_install_study <- function(
    location,
    registry_root = NULL,
    repo = NULL,
    folder = NULL,
    from_registry_index = FALSE
  ) {
    install_calls[[length(install_calls) + 1L]] <<- list(
      location = location,
      registry_root = registry_root,
      repo = repo,
      folder = folder,
      from_registry_index = from_registry_index
    )
    invisible(TRUE)
  }
  local_mocked_bindings(
    load_index = stub_load_index,
    install_study_dependencies = stub_install_study,
    .package = "replicateEverything"
  )
  out <- install_registry_dependencies(verbose = FALSE)
  expect_length(install_calls, 2L)
  expect_equal(install_calls[[1L]]$location, "10.1017/s0003055403000534")
  expect_true(install_calls[[1L]]$from_registry_index)
  expect_equal(install_calls[[2L]]$location, "rep-10.1017-S0003055403000534--alt-1")
  expect_true(install_calls[[2L]]$from_registry_index)
  expect_true(out[["rep-10.1017-S0003055403000534--alt-1"]]$ok)
})

test_that("install_registry_dependencies reports row context on failure", {
  idx <- data.frame(
    folder = "10.1017S0003055403000534",
    handle = "10.1017S0003055403000534",
    doi = "10.1017/s0003055403000534",
    repo = "replicate-anything/rep-10.1017-S0003055403000534",
    stringsAsFactors = FALSE
  )
  local_mocked_bindings(
    load_index = function() idx,
    install_study_dependencies = function(...) {
      stop("stub failure", call. = FALSE)
    },
    .package = "replicateEverything"
  )
  expect_warning(
    out <- install_registry_dependencies(verbose = FALSE),
    "Dependency install failed"
  )
  expect_false(out[["10.1017/s0003055403000534"]]$ok)
  expect_match(
    out[["10.1017/s0003055403000534"]]$error,
    "Registry row 1/1"
  )
  expect_match(
    out[["10.1017/s0003055403000534"]]$error,
    "location: 10.1017/s0003055403000534"
  )
})

test_that("from_registry_index rejects blank location without cwd lookup", {
  withr::local_tempdir()
  expect_error(
    replicateEverything:::prepare_doi_for_replication("", allow_local = FALSE),
    "Registry bulk install"
  )
})

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
    steps = list(list(id = "tab_1", engine = "r", type = "table")),
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

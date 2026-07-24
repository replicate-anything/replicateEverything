test_that("study_declared_languages prefers yaml languages field", {
  meta <- list(
    languages = c("r", "stata"),
    steps = list(
      list(id = "fig_1", engine = "python", code = "code/fig_1.py")
    )
  )
  expect_equal(
    replicateEverything:::study_declared_languages(meta),
    c("r", "stata")
  )
})

test_that("study_declared_languages infers from entries when yaml omits languages", {
  meta <- list(
    paper = list(),
    steps = list(
      list(id = "tab_1", engine = "stata", code = "code/tab_1.do"),
      list(id = "fig_1", engine = "r", code = "code/fig_1.R"),
      list(id = "step_1", type = "transform", engine = "python", code = "code/step.py")
    )
  )
  engines <- replicateEverything:::study_declared_languages(meta)
  expect_true(all(c("stata", "r", "python") %in% engines))
})

test_that("study_declared_r_packages reads paper.dependencies", {
  meta <- list(
    paper = list(dependencies = c("ggplot2", "haven"))
  )
  expect_equal(
    replicateEverything:::study_declared_r_packages(meta),
    c("ggplot2", "haven")
  )
})

test_that("study_declared_python_packages prefers python_dependencies", {
  meta <- list(
    python_dependencies = c("pandas", "numpy"),
    steps = list(
      list(id = "s1", engine = "python", dependencies = c("jupyter"))
    )
  )
  expect_equal(
    replicateEverything:::study_declared_python_packages(meta),
    c("pandas", "numpy")
  )
})

test_that("probe_r_packages reports missing CRAN packages", {
  probe <- replicateEverything:::probe_r_packages(c("stats", "__not_a_real_pkg_xyz__"))
  expect_false(probe$ok)
  expect_true("__not_a_real_pkg_xyz__" %in% probe$missing)
  expect_false("stats" %in% probe$missing)
})

test_that("study_system_compatibility checks fixture R study dependencies", {
  with_fixture_opts({
    audit <- replicateEverything:::study_system_compatibility(
      fixture_doi(),
      materialize_study = FALSE
    )
    expect_s3_class(audit, "study_system_compatibility")
    expect_equal(audit$languages, "r")
    expect_true(is.list(audit$dependencies$r))
    expect_true(is.logical(audit$ready))
  })
})

test_that("study_system_compatibility includes stata probe for fixture study", {
  with_fixture_stata_opts({
    audit <- replicateEverything:::study_system_compatibility(
      fixture_stata_doi(),
      materialize_study = TRUE
    )
    expect_s3_class(audit, "study_system_compatibility")
    expect_equal(audit$languages, "stata")
    expect_true(!is.null(audit$dependencies$stata))
    expect_false(identical(audit$dependencies$stata$probe, "not configured"))
  })
})

test_that("study_registry_audit_results filters audit snapshot by doi", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  registry_root <- file.path(monorepo_root, "registry")
  skip_if_not(file.exists(file.path(registry_root, "audit_latest.rds")), "audit snapshot missing")
  res <- replicateEverything:::study_registry_audit_results(
    "10.1017/S0003055426101749",
    registry_root = registry_root
  )
  expect_true(res$available)
  if (res$total > 0L) {
    expect_true(res$passed + res$failed == res$total)
  }
})

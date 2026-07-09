test_that("is_prep_entry does not treat figures with output as prep", {
  fig <- list(
    id = "fig_2",
    type = "figure",
    output = "artifacts/fig_2.png",
    artifact = "artifacts/fig_2.png"
  )
  expect_false(replicateEverything:::is_prep_entry(fig))
})

test_that("is_prep_entry recognizes pipeline steps", {
  step <- list(
    id = "construct_analysis_dataset",
    type = "step",
    output = "data/processed/all_asperson_fulldata.dta"
  )
  expect_true(replicateEverything:::is_prep_entry(step))
})

test_that("format_function_name adds _stata suffix for Stata format scripts", {
  rep <- list(
    id = "tab_2",
    type = "table",
    engine = "stata",
    format = "code/helpers/format_stata.R"
  )
  expect_equal(
    replicateEverything:::format_function_name(rep),
    "format_tab_2_stata"
  )
})

test_that("ensure_replication_dependencies skips Stata SSC packages on entries", {
  rep <- list(
    id = "tab_1",
    engine = "stata",
    dependencies = c("reghdfe", "estout")
  )
  paper <- list(dependencies = c("haven"))
  expect_silent(
    replicateEverything:::ensure_replication_dependencies(
      rep,
      paper_meta = paper,
      install_missing = FALSE
    )
  )
  expect_error(
    replicateEverything:::ensure_replication_dependencies(
      list(id = "tab_1", engine = "r", dependencies = "not_a_real_pkg_xyz"),
      paper_meta = list(),
      install_missing = FALSE
    ),
    "Missing required replication dependencies"
  )
})

test_that("prep_steps_for_build selects required prep in yaml order", {
  meta <- list(
    prep = list(
      list(id = "step_a", type = "step"),
      list(id = "step_b", type = "step"),
      list(id = "step_c", type = "step")
    ),
    replications = list(
      list(id = "fig_1", type = "figure", requires = list("step_c")),
      list(id = "tab_1", type = "table", requires = list("step_b", "step_a"))
    )
  )
  reps <- replicateEverything:::folder_display_replications(meta)
  steps <- replicateEverything:::prep_steps_for_build(meta, reps)
  expect_equal(vapply(steps, function(x) x$id, character(1)), c("step_a", "step_b", "step_c"))
  all_steps <- replicateEverything:::prep_steps_for_build(meta, NULL)
  expect_length(all_steps, 3L)
})

test_that("collect_required_prep_ids follows transitive requires", {
  meta <- list(
    prep = list(
      list(id = "step_a", type = "step"),
      list(id = "step_b", type = "step", requires = list("step_a"))
    ),
    replications = list(
      list(id = "fig_1", type = "figure", requires = list("step_b"))
    )
  )
  ids <- replicateEverything:::collect_required_prep_ids(
    meta,
    replicateEverything:::folder_display_replications(meta)
  )
  expect_equal(ids, c("step_a", "step_b"))
})

test_that("python_dep_import_name strips specifiers and maps known names", {
  imp <- replicateEverything:::python_dep_import_name
  expect_equal(imp("pandas"), "pandas")
  expect_equal(imp("pandas>=1.5"), "pandas")
  expect_equal(imp("numpy==1.26.0"), "numpy")
  expect_equal(imp("scikit-learn"), "sklearn")
  expect_equal(imp("pillow"), "PIL")
  expect_equal(imp("opencv-python"), "cv2")
  expect_equal(imp("pyyaml"), "yaml")
  expect_equal(imp("beautifulsoup4"), "bs4")
  expect_equal(imp("requests[security]"), "requests")
  expect_equal(imp("some-dist ; python_version >= '3.9'"), "some_dist")
})

test_that("python_replication_deps merges entry and study-wide packages", {
  rep <- list(id = "fig_2", engine = "python", dependencies = c("matplotlib"))
  meta <- list(
    python_dependencies = c("pandas", "numpy"),
    paper = list()
  )
  deps <- replicateEverything:::python_replication_deps(rep, meta)
  expect_true(all(c("matplotlib", "pandas", "numpy") %in% deps))
})

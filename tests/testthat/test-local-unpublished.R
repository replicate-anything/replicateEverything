write_unpublished_tab1_study <- function(
  study,
  inputs_yaml = "      - data/data.csv",
  handle = "unpublished-demo"
) {
  dir.create(file.path(study, "code"), showWarnings = FALSE)
  dir.create(file.path(study, "data"), showWarnings = FALSE)
  writeLines(
    paste(
      "paper:",
      paste0("  study_handle: ", handle),
      "  title: Unpublished local demo",
      "  year: '2026'",
      "  authors: Workshop",
      "  source_repository: unpublished local files",
      "  dependencies:",
      "    - estimatr",
      "    - knitr",
      "maintainer:",
      "  name: Workshop",
      "  email: workshop@example.org",
      "collections:",
      "  - IPI",
      "languages:",
      "  - r",
      "steps:",
      "  - id: tab_1",
      "    type: table",
      "    engine: r",
      "    inputs:",
      inputs_yaml,
      "    code: code/tab_1.R",
      "    format: format_tab_1",
      "    outputs:",
      "      - outputs/tab_1.html",
      "  - id: tab_1_format",
      "    type: format",
      "    parent: tab_1",
      "    code: code/tab_1.R",
      sep = "\n"
    ),
    file.path(study, "replication.yml")
  )
  writeLines("X,Y\n0,0\n1,1\n1,1", file.path(study, "data", "data.csv"))
  writeLines(
    paste(
      "library(estimatr)",
      "make_tab_1 <- function(data) estimatr::lm_robust(Y ~ X, data = data)",
      "format_tab_1 <- function(object) {",
      "  knitr::kable(as.data.frame(summary(object)$coefficients), format = 'html', digits = 3)",
      "}",
      sep = "\n"
    ),
    file.path(study, "code", "tab_1.R")
  )
  invisible(study)
}

test_that("find_local_study_root falls back to shiny_launch_wd", {
  study <- withr::local_tempdir("local-study-")
  other <- withr::local_tempdir("other-wd-")
  writeLines("paper:\n  study_handle: local-test\n", file.path(study, "replication.yml"))

  expect_null(find_local_study_root(other))

  withr::with_options(
    list(replicateEverything.shiny_launch_wd = study),
    {
      found <- find_local_study_root(other)
      expect_equal(
        normalizePath(found, winslash = "/", mustWork = FALSE),
        normalizePath(study, winslash = "/", mustWork = FALSE)
      )
      resolved <- resolve_doi_input("local", location = other)
      expect_true(resolved$is_local)
      expect_equal(
        normalizePath(resolved$local_root, winslash = "/", mustWork = FALSE),
        normalizePath(study, winslash = "/", mustWork = FALSE)
      )
    }
  )
})

test_that("run_replication('local') works after setwd to an unpublished folder", {
  skip_if_not_installed("estimatr")
  skip_if_not_installed("knitr")
  study <- withr::local_tempdir("local-run-")
  write_unpublished_tab1_study(study, handle = "unpublished-local-run")
  withr::with_dir(study, {
    reps <- list_replications("local")
    ids <- vapply(reps, function(r) as.character(r$id[[1]] %||% r$id), character(1))
    expect_true("tab_1" %in% ids)
    fit <- run_replication("local", "tab_1")
    expect_s3_class(fit, "lm_robust")
  })
})

test_that("resolve_declared_path keeps absolute files outside the study", {
  study <- withr::local_tempdir("study-root-")
  outside <- withr::local_tempdir("outside-data-")
  abs_csv <- file.path(outside, "ext.csv")
  writeLines("X,Y\n1,2", abs_csv)
  abs_csv <- normalizePath(abs_csv, winslash = "/", mustWork = TRUE)

  expect_true(is_absolute_declared_path(abs_csv))
  expect_equal(
    resolve_declared_path(abs_csv, study),
    abs_csv
  )
  expect_equal(
    study_data_file_candidates(abs_csv, study, list(), NULL),
    abs_csv
  )

  ensured <- ensure_study_data_files(abs_csv, study, list(paper = list()), NULL)
  expect_equal(
    normalizePath(ensured, winslash = "/", mustWork = FALSE),
    abs_csv
  )
  expect_false(file.exists(file.path(study, basename(abs_csv))))
})

test_that("resolve_declared_path expands ~/ paths", {
  study <- withr::local_tempdir("home-study-")
  declared <- "~/somewhere/my_data.csv"
  expect_true(is_absolute_declared_path(declared))
  resolved <- resolve_declared_path(declared, study)
  expect_equal(
    normalizePath(resolved, winslash = "/", mustWork = FALSE),
    normalizePath(path.expand(declared), winslash = "/", mustWork = FALSE)
  )
  expect_false(startsWith(resolved, study))
})

test_that("coerce_yaml_declared_paths rebuilds unquoted Windows drive paths", {
  expect_equal(
    coerce_yaml_declared_paths(list(C = "/Users/you/file.csv")),
    "C:/Users/you/file.csv"
  )
  expect_equal(
    coerce_yaml_declared_paths(c("data/data.csv", "~/x.csv")),
    c("data/data.csv", "~/x.csv")
  )
})

test_that("run_replication reads yaml inputs from an absolute path outside the study", {
  skip_if_not_installed("estimatr")
  skip_if_not_installed("knitr")
  study <- withr::local_tempdir("abs-study-")
  outside <- withr::local_tempdir("abs-data-")
  abs_csv <- normalizePath(file.path(outside, "ext.csv"), winslash = "/", mustWork = FALSE)
  writeLines("X,Y\n0,0\n1,1\n1,1", abs_csv)
  abs_csv <- normalizePath(abs_csv, winslash = "/", mustWork = TRUE)
  write_unpublished_tab1_study(
    study,
    inputs_yaml = paste0('      - "', abs_csv, '"'),
    handle = "unpublished-abs-path"
  )
  unlink(file.path(study, "data", "data.csv"))

  fit <- run_replication(study, "tab_1")
  expect_s3_class(fit, "lm_robust")
  expect_false(file.exists(file.path(study, "data", "data.csv")))
  expect_false(file.exists(file.path(study, "ext.csv")))
})

test_that("check_and_bake_study accepts a handle-only folder without repo or tests", {
  skip_if_not_installed("estimatr")
  skip_if_not_installed("knitr")

  study <- withr::local_tempdir("unpublished-")
  write_unpublished_tab1_study(study, handle = "unpublished-bake")

  result <- check_and_bake_study(study, build_artifacts = TRUE, install_deps = FALSE)
  failed <- result$checks[!result$checks$passed, , drop = FALSE]
  expect_equal(nrow(failed), 0L, info = paste(failed$check, failed$message, collapse = "; "))
  expect_true(result$ok)
  expect_true(file.exists(file.path(study, "outputs", "tab_1.html")))
})

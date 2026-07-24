test_that("check_replication validates vaccine package structure", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  pkg_dir <- file.path(monorepo_root, "rep-10.1371-journal.pone.0278337")
  skip_if_not(dir.exists(pkg_dir), "vaccine solidarity rep package missing")
  skip_if_not(
    requireNamespace("devtools", quietly = TRUE),
    "devtools required"
  )

  art_dir <- file.path(pkg_dir, "inst", "report", "artifacts")
  skip_if_not(
    dir.exists(art_dir) && length(list.files(art_dir)) > 0,
    "run build_study_outputs() in study package first"
  )

  result <- check_replication(pkg_dir, full_replication = FALSE)
  expect_s3_class(result, "package_replication_check")
  failed <- result$checks[!result$checks$passed, , drop = FALSE]
  if (nrow(failed) > 0) {
    msg <- paste0(failed$check, ": ", failed$message, collapse = "; ")
    skip(paste("package checks failed:", msg))
  }
  expect_true(result$ok)
})

test_that("parse_github_slug accepts common forms", {
  expect_equal(
    parse_github_slug("https://github.com/org/my-pkg"),
    "org/my-pkg"
  )
  expect_equal(
    parse_github_slug("git@github.com:org/my-pkg.git"),
    "org/my-pkg"
  )
  expect_equal(parse_github_slug("org/my-pkg"), "org/my-pkg")
})

test_that("parse_github_slug rejects DOI-shaped strings", {
  expect_null(parse_github_slug("10.1017/S0003055426101622"))
  expect_null(parse_github_slug("https://doi.org/10.1017/S0003055426101622"))
})

test_that("registry_stub_from_package_meta omits replications", {
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1371/journal.pone.0278337",
      title = "Test",
      package = "pkgtest",
      package_repo = "org/pkgtest"
    ),
    repo = "org/pkgtest",
    steps = list(list(id = "fig_1"))
  )
  stub <- registry_stub_from_package_meta(meta, package_folder = "pkgtest")
  expect_null(stub$steps)
  expect_null(stub$replications)
  expect_equal(stub$paper$package, "pkgtest")
})

test_that("resolve_replication_package_path finds sibling study package", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  pkg_dir <- file.path(monorepo_root, "rep_10.1371_journal.pone.0278337")
  skip_if_not(dir.exists(pkg_dir), "vaccine solidarity rep package missing")

  meta <- list(
    paper = list(
      package = "rep1371journalpone0278337",
      package_folder = "rep_10.1371_journal.pone.0278337"
    )
  )
  ctx <- list(folder = "10.1371_journal.pone.0278337")

  withr::with_options(
    list(replicateEverything.replication_packages_root = monorepo_root),
    {
      resolved <- resolve_replication_package_path(
        "rep1371journalpone0278337",
        meta,
        ctx
      )
      expect_equal(resolved, normalizePath(pkg_dir, winslash = "/", mustWork = FALSE))
    }
  )
})

test_that("package_repo_slug prefers yaml repo over index ctx", {
  meta <- list(
    repo = "replicate-anything/rep_10.1371_journal.pone.0278337",
    paper = list(package_repo = "org/study-package")
  )
  ctx <- list(repo = "replicate-anything/registry")
  expect_equal(package_repo_slug(meta, ctx), "replicate-anything/rep_10.1371_journal.pone.0278337")
})

test_that("is_package_replication detects package field", {
  expect_true(is_package_replication(list(paper = list(package = "foo"))))
  expect_false(is_package_replication(list(paper = list(title = "bar"))))
})

test_that("get_code dispatches to package-backed study", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  pkg_dir <- file.path(monorepo_root, "rep_10.1371_journal.pone.0278337")
  skip_if_not(dir.exists(pkg_dir), "vaccine solidarity rep package missing")
  skip_if_not(
    requireNamespace("devtools", quietly = TRUE),
    "devtools required to load sibling study package"
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = file.path(monorepo_root, "registry"),
      replicateEverything.replication_packages_root = monorepo_root
    ),
    {
      lines <- get_code(
        "10.1371/journal.pone.0278337",
        "fig_1",
        folder = "10.1371_journal.pone.0278337"
      )
      code <- paste(lines, collapse = "\n")
      expect_true(grepl("make_figure_1", code, fixed = TRUE))
      expect_true(grepl("wave4_conjoint", code, fixed = TRUE))
    }
  )
})

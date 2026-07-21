test_that("resolve_replication_package_path finds sibling study package", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  pkg_dir <- file.path(monorepo_root, "rep-10.1371-journal.pone.0278337")
  skip_if_not(dir.exists(pkg_dir), "vaccine solidarity rep package missing")

  meta <- list(
    paper = list(
      package = "rep1371journalpone0278337",
      package_folder = "rep-10.1371-journal.pone.0278337"
    )
  )
  ctx <- list(folder = "10.1371_journal.pone.0278337")

  withr::with_options(
    list(
      replicateEverything.replication_packages_root = monorepo_root,
      replicateEverything.use_sibling_packages = TRUE
    ),
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
    repo = "replicate-anything/rep-10.1371-journal.pone.0278337",
    paper = list(package_repo = "org/study-package")
  )
  ctx <- list(repo = "replicate-anything/registry")
  expect_equal(package_repo_slug(meta, ctx), "replicate-anything/rep-10.1371-journal.pone.0278337")
})

test_that("github_remote_sha returns NA for invalid repo", {
  expect_equal(
    github_remote_sha("replicate-anything/nonexistent-repo-xyz", "main"),
    NA_character_
  )
})

test_that("installed_package_remote_sha returns NA for missing package", {
  expect_equal(
    installed_package_remote_sha("nonexistent_package_xyz_123"),
    NA_character_
  )
})

test_that("read_yaml_url loads vaccine study package replication.yml", {
  skip_on_cran()
  url <- paste0(
    "https://raw.githubusercontent.com/",
    "replicate-anything/rep-10.1371-journal.pone.0278337/main/inst/replication.yml"
  )
  meta <- read_yaml_url(url)
  skip_if(is.null(meta), "could not reach GitHub")
  expect_gt(length(meta$replications %||% list()), 0)
})

test_that("list_replications lists figures without installing study package", {
  skip_on_cran()
  if (requireNamespace("rep1371journalpone0278337", quietly = TRUE)) {
    try(detach(paste0("package:", "rep1371journalpone0278337"), unload = TRUE), silent = TRUE)
  }
  reps <- list_replications(
    "10.1371/journal.pone.0278337",
    folder = "10.1371_journal.pone.0278337"
  )
  types <- vapply(reps, function(x) as.character(x$type %||% ""), character(1))
  expect_true(any(types == "figure"))
  expect_true(any(types == "table"))
})

test_that("fetch_package_replication_yaml loads study metadata without install", {
  skip_on_cran()
  meta <- list(
    repo = "replicate-anything/rep-10.1371-journal.pone.0278337",
    paper = list(
      package = "rep1371journalpone0278337",
      package_ref = "main"
    )
  )
  ctx <- list(folder = "10.1371_journal.pone.0278337", repo = "replicate-anything/registry")
  pkg_meta <- fetch_package_replication_yaml(meta, ctx)
  skip_if(is.null(pkg_meta), "could not reach GitHub")
  expect_gt(length(pkg_meta$replications %||% list()), 0)
})

test_that("enrich_package_replication_meta merges remote package yaml", {
  skip_on_cran()
  stub <- list(
    repo = "replicate-anything/rep-10.1371-journal.pone.0278337",
    paper = list(
      package = "rep1371journalpone0278337",
      package_ref = "main"
    )
  )
  ctx <- list(folder = "10.1371_journal.pone.0278337", repo = "replicate-anything/registry")
  enriched <- enrich_package_replication_meta(stub, ctx)
  skip_if(length(enriched$replications %||% list()) == 0, "could not reach GitHub")
  expect_true(any(vapply(enriched$replications, function(x) identical(x$id, "fig_1"), logical(1))))
})

test_that("load_artifact reads package html when study package is loaded", {
  skip_if_not_installed("rep1371journalpone0278337")

  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  pkg_dir <- file.path(monorepo_root, "rep-10.1371-journal.pone.0278337")
  skip_if_not(dir.exists(pkg_dir), "vaccine solidarity rep package missing")
  skip_if_not(
    requireNamespace("devtools", quietly = TRUE),
    "devtools required to load sibling study package"
  )

  tab <- file.path(pkg_dir, "inst", "report", "artifacts", "tab_1.html")
  skip_if_not(file.exists(tab), "package tab_1 artifact missing; run build_report()")

  withr::with_options(
    list(
      replicateEverything.replication_packages_root = monorepo_root,
      replicateEverything.use_sibling_packages = TRUE
    ),
    {
      html <- load_artifact(
        "10.1371/journal.pone.0278337",
        "tab_1",
        folder = "10.1371_journal.pone.0278337"
      )
      expect_true(is.character(html))
      expect_true(grepl("<table", html, ignore.case = TRUE))
    }
  )
})

test_that("format_for_display passes through package-backed output", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  pkg_dir <- file.path(monorepo_root, "rep-10.1371-journal.pone.0278337")
  skip_if_not(dir.exists(pkg_dir), "vaccine solidarity rep package missing")
  skip_if_not(
    requireNamespace("devtools", quietly = TRUE),
    "devtools required to load sibling study package"
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = file.path(monorepo_root, "registry"),
      replicateEverything.replication_packages_root = monorepo_root,
      replicateEverything.use_sibling_packages = TRUE
    ),
    {
      result <- render_replication(
        "10.1371/journal.pone.0278337",
        "fig_2",
        folder = "10.1371_journal.pone.0278337"
      )
      obj <- replication_object(result)
      display <- format_for_display(
        obj,
        "10.1371/journal.pone.0278337",
        "fig_2",
        folder = "10.1371_journal.pone.0278337"
      )
      expect_identical(display, obj)
    }
  )
})

test_that("find_replication_entry reads package yaml when registry stub is minimal", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  stub <- file.path(
    monorepo_root,
    "registry",
    "studies",
    "10.1371_journal.pone.0278337.yml"
  )
  skip_if_not(file.exists(stub), "registry stub missing")
  skip_if_not(
    requireNamespace("devtools", quietly = TRUE),
    "devtools required to load sibling study package"
  )

  withr::with_options(
    list(
      replicateEverything.replication_packages_root = monorepo_root,
      replicateEverything.use_sibling_packages = TRUE
    ),
    {
      devtools::load_all(
        file.path(monorepo_root, "rep-10.1371-journal.pone.0278337"),
        quiet = TRUE
      )
      meta <- yaml::read_yaml(stub)
      rep <- find_replication_entry(meta, "fig_1")
      expect_equal(rep$id, "fig_1")
      expect_equal(rep$type, "figure")
    }
  )
})

test_that("get_code dispatches to package-backed study", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  pkg_dir <- file.path(monorepo_root, "rep-10.1371-journal.pone.0278337")
  skip_if_not(dir.exists(pkg_dir), "vaccine solidarity rep package missing")
  skip_if_not(
    requireNamespace("devtools", quietly = TRUE),
    "devtools required to load sibling study package"
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = file.path(monorepo_root, "registry"),
      replicateEverything.replication_packages_root = monorepo_root,
      replicateEverything.use_sibling_packages = TRUE
    ),
    {
      lines <- replicateEverything::get_code(
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

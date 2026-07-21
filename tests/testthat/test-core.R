test_that("normalize_doi strips prefixes", {
  expect_equal(
    normalize_doi("https://doi.org/10.1177/00491241211036161"),
    "10.1177/00491241211036161"
  )
})

test_that("resolve_paper_path uses index folder when available", {
  local_index <- data.frame(
    folder = c("10.5555_cahw"),
    doi = c("https://doi.org/10.5555/cahw"),
    title = "Example",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/registry",
    stringsAsFactors = FALSE
  )

  withr::with_options(
    list(replicateEverything.index = local_index),
    {
      expect_equal(
        resolve_paper_path("10.5555/cahw"),
        "10.5555_cahw"
      )
    }
  )
})

test_that("resolve_paper_path uses Fearon folder from index", {
  local_index <- data.frame(
    folder = "10.1017S0003055403000534",
    doi = "https://doi.org/10.1017/S0003055403000534",
    title = "Ethnicity, Insurgency, and Civil War",
    journal = "APSR",
    year = 2003,
    authors = "Fearon, Laitin",
    repo = "replicate-anything/registry",
    stringsAsFactors = FALSE
  )

  withr::with_options(
    list(replicateEverything.index = local_index),
    {
      expect_equal(
        resolve_paper_path("10.1017/S0003055403000534"),
        "10.1017S0003055403000534"
      )
    }
  )
})

test_that("paper_context routes folder-backed studies to study repo root", {
  registry_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "registry"),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(dir.exists(registry_root), "registry missing")

  local_index <- data.frame(
    folder = "10.1017S0003055403000534",
    doi = "https://doi.org/10.1017/S0003055403000534",
    title = "Ethnicity, Insurgency, and Civil War",
    journal = "APSR",
    year = 2003,
    authors = "Fearon, Laitin",
    repo = "replicate-anything/rep-10.1017-S0003055403000534",
    stringsAsFactors = FALSE
  )

  withr::with_options(
    list(
      replicateEverything.index = local_index,
      replicateEverything.registry_root = registry_root
    ),
    {
      ctx <- paper_context("10.1017/S0003055403000534")
      expect_true(isTRUE(ctx$is_folder_study))
      expect_equal(
        ctx$base_url,
        "https://raw.githubusercontent.com/replicate-anything/rep-10.1017-S0003055403000534/main/"
      )
      expect_equal(
        ctx$materials_repo,
        "replicate-anything/rep-10.1017-S0003055403000534"
      )
    }
  )
})

test_that("resolve_paper_path fallback differs from Fearon folder", {
  expect_equal(
    gsub("/", "_", normalize_doi("10.1017/S0003055403000534")),
    "10.1017_s0003055403000534"
  )
  expect_false(
    identical(
      gsub("/", "_", normalize_doi("10.1017/S0003055403000534")),
      "10.1017S0003055403000534"
    )
  )
})

test_that("read_data_path handles csv and rds", {
  tmp_csv <- tempfile(fileext = ".csv")
  write.csv(data.frame(x = 1:2, y = 3:4), tmp_csv, row.names = FALSE)
  out_csv <- read_data_path(tmp_csv, "csv")
  expect_equal(nrow(out_csv), 2)

  tmp_rds <- tempfile(fileext = ".rds")
  saveRDS(list(a = 1), tmp_rds)
  out_rds <- read_data_path(tmp_rds, "rds")
  expect_equal(out_rds$a, 1)
})

test_that("infer_result_format detects common outputs", {
  expect_equal(infer_result_format(data.frame(x = 1), "table"), "data.frame")
  expect_equal(infer_result_format("<table></table>", "table"), "html")
  png_path <- tempfile(fileext = ".png")
  writeBin(as.raw(0), png_path)
  expect_equal(infer_result_format(png_path, "figure"), "png")
})

test_that("render_replication works against local fixture", {
  fixture_root <- normalizePath(
    file.path(testthat::test_path(".."), "fixtures", "registry"),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(dir.exists(fixture_root), "fixture registry missing")

  local_index <- data.frame(
    folder = "10.9999_example",
    doi = "https://doi.org/10.9999/example",
    title = "Fixture Paper",
    journal = "Test Journal",
    year = 2025,
    authors = "Test Author",
    repo = "replicate-anything/rep-10.9999-example",
    stringsAsFactors = FALSE
  )

  fixtures_root <- normalizePath(
    file.path(testthat::test_path(".."), "fixtures"),
    winslash = "/",
    mustWork = FALSE
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = fixture_root,
      replicateEverything.index = local_index,
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.study_folders_root = fixtures_root
    ),
    {
      result <- render_replication("10.9999/example", "tab_1")
      expect_s3_class(result, "replication_result")
      expect_equal(result$format, "data.frame")
      expect_equal(nrow(replication_object(result)), 2)
    }
  )
})

test_that("save_artifact writes html for tables", {
  tmp <- tempfile()
  dir.create(tmp)
  result <- structure(
    list(
      id = "tab_1",
      type = "table",
      object = data.frame(x = 1:2),
      format = "data.frame",
      meta = list(id = "tab_1")
    ),
    class = "replication_result"
  )
  path <- save_artifact(result, tmp)
  expect_true(file.exists(path))
  expect_true(grepl("<table", readLines(path, n = 1)))
})

test_that("run_replication can apply format when requested", {
  testthat::skip_if_not_installed("modelsummary")
  testthat::skip_if_not_installed("kableExtra")

  registry_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "registry"),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(dir.exists(registry_root), "registry missing")

  monorepo_root <- normalizePath(
    file.path(registry_root, ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_root <- file.path(monorepo_root, "rep-10.1017-S0003055403000534")
  skip_if_not(
    dir.exists(study_root) && file.exists(file.path(study_root, "replication.yml")),
    "folder-backed Fearon study repo missing"
  )

  local_index <- data.frame(
    folder = "10.1017S0003055403000534",
    doi = "https://doi.org/10.1017/S0003055403000534",
    title = "Ethnicity, Insurgency, and Civil War",
    journal = "APSR",
    year = 2003,
    authors = "Fearon, Laitin",
    repo = "replicate-anything/rep-10.1017-S0003055403000534",
    stringsAsFactors = FALSE
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = registry_root,
      replicateEverything.index = local_index,
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.study_folders_root = monorepo_root
    ),
    {
      invisible(suppressMessages(capture.output({
        raw <- replicateEverything::run_replication(
          "10.1017/s0003055403000534",
          "tab_1",
          folder = "10.1017S0003055403000534",
          format = FALSE
        )
      })))
      expect_type(raw, "list")

      invisible(suppressMessages(capture.output({
        formatted <- replicateEverything::run_replication(
          "10.1017/s0003055403000534",
          "tab_1",
          folder = "10.1017S0003055403000534",
          format = TRUE
        )
      })))
      expect_true(is.character(formatted))
      expect_true(grepl("<table", formatted, ignore.case = TRUE))
    }
  )
})

test_that("save_artifact writes html when format step is registered", {
  tmp <- tempfile()
  dir.create(tmp)
  skip_if_not_installed("modelsummary")
  skip_if_not_installed("kableExtra")

  registry_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", "..", "registry"),
    winslash = "/",
    mustWork = FALSE
  )
  skip_if_not(dir.exists(registry_root), "registry missing")

  monorepo_root <- normalizePath(
    file.path(registry_root, ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_root <- file.path(monorepo_root, "rep-10.1017-S0003055403000534")
  skip_if_not(
    dir.exists(study_root) && file.exists(file.path(study_root, "replication.yml")),
    "folder-backed Fearon study repo missing"
  )

  local_index <- data.frame(
    folder = "10.1017S0003055403000534",
    doi = "https://doi.org/10.1017/S0003055403000534",
    title = "Ethnicity, Insurgency, and Civil War",
    journal = "APSR",
    year = 2003,
    authors = "Fearon, Laitin",
    repo = "replicate-anything/rep-10.1017-S0003055403000534",
    stringsAsFactors = FALSE
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = registry_root,
      replicateEverything.index = local_index,
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.study_folders_root = monorepo_root
    ),
    {
      result <- render_replication(
        "10.1017/s0003055403000534",
        "tab_1",
        folder = "10.1017S0003055403000534",
        install_deps = FALSE
      )
      path <- save_artifact(
        result,
        tmp,
        doi = "10.1017/s0003055403000534",
        folder = "10.1017S0003055403000534"
      )
      expect_true(file.exists(path))
      expect_equal(tools::file_ext(path), "html")
      expect_true(grepl("<table", readLines(path, n = 1), ignore.case = TRUE))
    }
  )
})

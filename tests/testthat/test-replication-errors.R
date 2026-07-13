test_that("strip_ansi_escapes removes color and hyperlink codes", {
  colored <- paste0("file \033[34m./data/raw/foo\033[0m path")
  expect_equal(strip_ansi_escapes(colored), "file ./data/raw/foo path")

  linked <- paste0(
    "missing \033]8;;file:///path\033\\./data/raw/foo\033[0m"
  )
  expect_equal(strip_ansi_escapes(linked), "missing ./data/raw/foo")
})

test_that("replication_error_message strips Stata-style hyperlinks", {
  msg <- paste0("file not found: \033]8;;file:///path\033\\./data/raw/foo\033[0m")
  err <- simpleError(msg)
  expect_equal(replication_error_message(err), "file not found: ./data/raw/foo")
})

test_that("get_artifact_path resolves figure from fixture study folder", {
  skip_on_cran()
  with_fixture_opts({
    study <- file.path(
      testthat::test_path(".."), "fixtures", "rep-10.9999_example"
    )
    png_path <- file.path(study, "artifacts", "fig_1.png")
    dir.create(dirname(png_path), recursive = TRUE, showWarnings = FALSE)
    writeBin(as.raw(0), png_path)
    on.exit(unlink(png_path), add = TRUE)

    path <- get_artifact_path(
      fixture_doi(),
      "fig_1",
      folder = "10.9999_example",
      language = "r"
    )
    expect_false(is.null(path))
    expect_true(grepl("fig_1\\.png$", path))
  })
})

test_that("get_artifact_path returns NULL when replication entry lookup fails", {
  skip_on_cran()
  with_fixture_opts({
    path <- get_artifact_path(
      fixture_doi(),
      "fig_2_not_in_meta",
      folder = "10.9999_example",
      language = "r"
    )
    expect_null(path)
  })
})

test_that("infer_folder_study_stub finds study repo from rep slug", {
  skip_on_cran()
  stub <- infer_folder_study_stub("10.1017/S0003055426101749")
  expect_false(is.null(stub))
  expect_equal(
    tolower(as.character(stub$repo[[1]])),
    "replicate-anything/rep-10.1017-s0003055426101749"
  )
})

test_that("resolve_registry_artifact_path prefers the local declared artifact", {
  tmp <- tempfile()
  dir.create(tmp)
  dir.create(file.path(tmp, "outputs"), recursive = TRUE)
  png_path <- file.path(tmp, "outputs", "fig_2.png")
  writeBin(as.raw(0), png_path)

  rep <- list(id = "fig_2", type = "figure", artifact = "outputs/fig_2.png")
  ctx <- list(local_root = tmp, base_url = "https://example.com/main")

  resolved <- resolve_registry_artifact_path("fig_2", ctx, rep)
  expect_equal(
    normalizePath(resolved, winslash = "/", mustWork = FALSE),
    normalizePath(png_path, winslash = "/", mustWork = FALSE)
  )
})

test_that("resolve_registry_artifact_path returns the registry URL when no local file", {
  ctx <- list(local_root = NULL, base_url = "https://example.com/main")
  rep <- list(id = "fig_2", type = "figure", artifact = "outputs/fig_2.png")
  expect_equal(
    resolve_registry_artifact_path("fig_2", ctx, rep),
    "https://example.com/main/outputs/fig_2.png"
  )
})

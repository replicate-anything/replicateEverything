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

test_that("get_artifact_path resolves python figure when language is stata", {
  skip_on_cran()
  skip_if_not_installed("httr")
  withr::local_options(list(
    replicateEverything.registry_root = "c:/WZB Dropbox/Macartan Humphreys/5_github/replicate_everything/registry",
    replicateEverything.study_folders_root = NULL,
    replicateEverything.use_sibling_packages = FALSE
  ))
  path <- get_artifact_path(
    "10.1017/S0003055426101749",
    "fig_2",
    folder = "10.1017S0003055426101749",
    language = "stata"
  )
  expect_false(is.null(path))
  expect_true(
    grepl("fig_2\\.png$", path) ||
      grepl("fig_2\\.png$", basename(path))
  )
})

test_that("get_artifact_path resolves by id when replication entry lookup fails", {
  skip_on_cran()
  skip_if_not_installed("httr")
  withr::local_options(list(
    replicateEverything.registry_root = NULL,
    replicateEverything.study_folders_root = NULL,
    replicateEverything.use_sibling_packages = FALSE
  ))
  path <- get_artifact_path(
    "10.1017/S0003055426101749",
    "fig_2_not_in_meta",
    folder = "10.1017S0003055426101749",
    language = "stata"
  )
  expect_null(path)
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
  dir.create(file.path(tmp, "artifacts"))
  png_path <- file.path(tmp, "artifacts", "fig_2.png")
  writeBin(as.raw(0), png_path)

  rep <- list(id = "fig_2", type = "figure", artifact = "artifacts/fig_2.png")
  ctx <- list(local_root = tmp, base_url = "https://example.com/main")

  resolved <- resolve_registry_artifact_path("fig_2", ctx, rep)
  expect_equal(
    normalizePath(resolved, winslash = "/", mustWork = FALSE),
    normalizePath(png_path, winslash = "/", mustWork = FALSE)
  )
})

test_that("resolve_registry_artifact_path returns the registry URL when no local file", {
  ctx <- list(local_root = NULL, base_url = "https://example.com/main")
  rep <- list(id = "fig_2", type = "figure", artifact = "artifacts/fig_2.png")
  expect_equal(
    resolve_registry_artifact_path("fig_2", ctx, rep),
    "https://example.com/main/artifacts/fig_2.png"
  )
})

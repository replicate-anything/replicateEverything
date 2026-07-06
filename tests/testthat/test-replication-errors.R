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

test_that("manifest_artifact_paths reads flat artifacts map", {
  tmp <- tempfile()
  dir.create(tmp)
  dir.create(file.path(tmp, "artifacts"))
  manifest <- list(
    artifacts = list(fig_2 = "artifacts/fig_2.png")
  )
  jsonlite::write_json(
    manifest,
    file.path(tmp, "artifacts", "manifest.json"),
    auto_unbox = TRUE
  )
  paths <- manifest_artifact_paths(
    "fig_2",
    list(local_root = tmp, base_url = "https://example.com/main/")
  )
  expect_true(any(grepl("fig_2\\.png$", paths)))
})

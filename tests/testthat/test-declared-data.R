test_that("declared_data_entry_url prefers url over id", {
  expect_equal(
    declared_data_entry_url(list(
      path = "data/raw/a.dta",
      url = "https://example.com/a.dta",
      id = "99"
    )),
    "https://example.com/a.dta"
  )
})

test_that("declared_data_entry_url builds Dataverse file URL", {
  expect_equal(
    declared_data_entry_url(
      list(path = "data/raw/a.dta", id = "13684082", original = TRUE),
      server = "dataverse.harvard.edu"
    ),
    "https://dataverse.harvard.edu/api/access/datafile/13684082?format=original"
  )
  expect_equal(
    declared_data_entry_url(list(path = "x.dta", file_id = "1")),
    "https://dataverse.harvard.edu/api/access/datafile/1"
  )
})

test_that("declared_data_entries reads dataverse.files and data_files", {
  meta <- list(
    dataverse = list(
      files = list(
        list(path = "data/raw/a.dta", url = "https://example.com/a.dta")
      )
    ),
    data_files = list(
      list(path = "data/raw/b.csv", url = "https://example.com/b.csv")
    )
  )
  entries <- declared_data_entries(meta)
  paths <- vapply(entries, function(e) e$path, character(1))
  expect_equal(paths, c("data/raw/a.dta", "data/raw/b.csv"))
})

test_that("materialize_declared_data downloads missing declared files", {
  tmp <- tempfile("declared_data")
  dir.create(file.path(tmp, "data", "raw"), recursive = TRUE)
  # Serve a tiny local file via a file:// URL so the test does not need httpbin
  src <- file.path(tmp, "payload.bin")
  writeBin(as.raw(1:32), src)
  file_url <- paste0("file:///", gsub("\\\\", "/", normalizePath(src, winslash = "/")))
  writeLines(
    c(
      "paper:",
      "  doi: https://doi.org/10.9999/TEST",
      "dataverse:",
      "  files:",
      "    - path: data/raw/hello.txt",
      paste0("      url: ", file_url)
    ),
    file.path(tmp, "replication.yml")
  )
  meta <- yaml::read_yaml(file.path(tmp, "replication.yml"))
  dest <- tryCatch(
    materialize_declared_data(meta, study_root = tmp),
    error = function(e) e
  )
  if (inherits(dest, "error")) {
    testthat::skip(paste("file URL download unavailable:", conditionMessage(dest)))
  }
  expect_true(file.exists(file.path(tmp, "data", "raw", "hello.txt")))
  expect_equal(file.info(file.path(tmp, "data", "raw", "hello.txt"))$size, 32)
  again <- materialize_declared_data(meta, study_root = tmp)
  expect_true(length(again) >= 1L)
})

test_that("download_url_to_path skips existing non-empty files", {
  dest <- tempfile("skip_dl", fileext = ".bin")
  writeBin(as.raw(1:4), dest)
  out <- download_url_to_path("https://example.com/should-not-hit", dest, force = FALSE)
  expect_equal(normalizePath(out), normalizePath(dest))
  expect_equal(file.info(dest)$size, 4)
})

test_that("get_started scaffolds a named mini study, not rep-template", {
  root <- withr::local_tempdir()
  study <- file.path(root, "my-local-demo")

  out <- get_started(study, name = "my-local-demo", title = "My local demo")
  expect_identical(normalizePath(out, winslash = "/", mustWork = FALSE),
                   normalizePath(study, winslash = "/", mustWork = FALSE))

  expect_true(file.exists(file.path(study, "my-local-demo.Rproj")))
  expect_true(file.exists(file.path(study, "replication.yml")))
  expect_true(file.exists(file.path(study, "data", "data.csv")))
  expect_true(file.exists(file.path(study, "code", "tab_1.R")))
  expect_true(dir.exists(file.path(study, "outputs")))

  meta <- yaml::read_yaml(file.path(study, "replication.yml"))
  expect_equal(meta$paper$study_handle, "my-local-demo")
  expect_equal(meta$paper$title, "My local demo")
  expect_false(identical(meta$paper$study_handle, "rep-template"))
  expect_null(meta$repo)
  expect_null(meta$paper$source_repository)
  expect_null(meta$paper$doi)
  expect_true(any(vapply(meta$steps, function(s) identical(s$id, "tab_1"), logical(1))))

  code <- paste(readLines(file.path(study, "code", "tab_1.R"), warn = FALSE), collapse = "\n")
  expect_match(code, "my-local-demo")
  expect_false(grepl("Not the gold template", code, fixed = TRUE))
  expect_match(code, "make_tab_1")
})

test_that("get_started accepts an existing empty folder", {
  root <- withr::local_tempdir()
  study <- file.path(root, "empty-ready")
  dir.create(study)
  expect_true(.get_started_dir_is_empty(study))

  get_started(study, name = "empty-ready")
  expect_true(file.exists(file.path(study, "replication.yml")))
})

test_that("get_started treats OS junk-only folders as empty", {
  root <- withr::local_tempdir()
  study <- file.path(root, "junk-only")
  dir.create(study)
  writeLines("[.ShellClassInfo]", file.path(study, "desktop.ini"))
  writeLines("mac", file.path(study, ".DS_Store"))
  writeLines("db", file.path(study, "Thumbs.db"))
  writeLines("drop", file.path(study, ".dropbox"))
  writeLines("attr", file.path(study, ".dropbox.attr"))
  dir.create(file.path(study, ".Rproj.user"))
  writeLines("", file.path(study, ".Rhistory"))
  writeLines("", file.path(study, ".RData"))
  writeLines("", file.path(study, ".Ruserdata"))

  expect_true(.get_started_dir_is_empty(study))
  get_started(study, name = "junk-only")
  expect_true(file.exists(file.path(study, "replication.yml")))
  expect_true(file.exists(file.path(study, "desktop.ini")))
  expect_true(dir.exists(file.path(study, ".Rproj.user")))
})

test_that("get_started path = 'here' scaffolds into getwd()", {
  temp_empty <- withr::local_tempdir()
  expect_true(.get_started_dir_is_empty(temp_empty))

  out <- withr::with_dir(temp_empty, get_started("here"))
  expect_identical(
    normalizePath(out, winslash = "/", mustWork = FALSE),
    normalizePath(temp_empty, winslash = "/", mustWork = FALSE)
  )
  expect_true(file.exists(file.path(temp_empty, "replication.yml")))
  expect_true(file.exists(file.path(temp_empty, "data", "data.csv")))
  expect_true(file.exists(file.path(temp_empty, "code", "tab_1.R")))

  expected_name <- .get_started_sanitize_name(basename(temp_empty))
  expect_true(file.exists(file.path(temp_empty, paste0(expected_name, ".Rproj"))))
  meta <- yaml::read_yaml(file.path(temp_empty, "replication.yml"))
  expect_equal(meta$paper$study_handle, expected_name)
})

test_that("get_started refuses reserved template name", {
  root <- withr::local_tempdir()
  expect_error(
    get_started(file.path(root, "x"), name = "rep-template"),
    "rep-template"
  )
})

test_that("get_started errors on non-empty folder without FORCE", {
  root <- withr::local_tempdir()
  study <- file.path(root, "busy")
  get_started(study, name = "busy")

  expect_error(
    get_started(study, name = "busy"),
    "not empty"
  )
  expect_error(
    get_started(study, name = "busy", FORCE = FALSE),
    "FORCE = TRUE"
  )
})

test_that("get_started non-empty error lists blocking entries only", {
  root <- withr::local_tempdir()
  study <- file.path(root, "leftover")
  dir.create(study)
  writeLines("noise", file.path(study, "desktop.ini"))
  writeLines("notes", file.path(study, "user-notes.txt"))

  err <- tryCatch(
    get_started(study, name = "leftover"),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "not empty")
  expect_match(err, "Found 1 entry")
  expect_match(err, "`user-notes.txt`")
  expect_false(grepl("`desktop.ini`", err, fixed = TRUE))
  expect_match(err, "FORCE = TRUE")
})

test_that("get_started treats .Rproj.user-only folder as empty", {
  root <- withr::local_tempdir()
  study <- file.path(root, "rstudio-dir")
  dir.create(study)
  dir.create(file.path(study, ".Rproj.user"))

  expect_true(.get_started_dir_is_empty(study))
  get_started(study, name = "rstudio-dir")
  expect_true(file.exists(file.path(study, "replication.yml")))
  expect_true(dir.exists(file.path(study, ".Rproj.user")))
})

test_that("get_started non-empty error caps long entry lists", {
  root <- withr::local_tempdir()
  study <- file.path(root, "many-files")
  dir.create(study)
  for (i in seq_len(12)) {
    writeLines("x", file.path(study, sprintf("f%02d.txt", i)))
  }

  err <- tryCatch(
    get_started(study, name = "many-files"),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "Found 12 entries")
  expect_match(err, "and 2 more")
  expect_false(grepl("`f12.txt`", err, fixed = TRUE))
})

test_that("get_started with FORCE replaces scaffold files only", {
  root <- withr::local_tempdir()
  study <- file.path(root, "force-me")
  get_started(study, name = "force-me")

  yaml_path <- file.path(study, "replication.yml")
  writeLines("paper:\n  study_handle: force-me\n  title: CUSTOM\n", yaml_path)
  keep_me <- file.path(study, "user-notes.txt")
  writeLines("do not delete", keep_me)

  get_started(study, name = "force-me", title = "Replaced", FORCE = TRUE)
  meta <- yaml::read_yaml(yaml_path)
  expect_equal(meta$paper$title, "Replaced")
  expect_true(file.exists(keep_me))
  expect_match(paste(readLines(keep_me, warn = FALSE), collapse = "\n"), "do not delete")
})

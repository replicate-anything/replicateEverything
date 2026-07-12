# Core user-facing API — run before export surface changes.

test_that("load_index respects replicateEverything.index option", {
  with_fixture_opts({
    idx <- load_index()
    expect_true(is.data.frame(idx))
    expect_true(nrow(idx) >= 1L)
    expect_true("doi" %in% names(idx))
    expect_true(any(grepl("Fixture", idx$title, ignore.case = TRUE)))
  })
})

test_that("search_papers finds fixture study by title", {
  with_fixture_opts({
    hits <- search_papers("fixture")
    expect_true(is.data.frame(hits))
    expect_true(nrow(hits) >= 1L)
  })
})

test_that("list_replications returns fixture ids", {
  with_fixture_opts({
    reps <- list_replications(fixture_doi())
    expect_s3_class(reps, "replication_list")
    expect_true(length(reps) >= 2L)
    ids <- vapply(reps, function(x) as.character(x$id), character(1))
    expect_true(all(c("fig_1", "tab_1") %in% ids))
  })
})

test_that("print.replication_list shows compact table", {
  with_fixture_opts({
    reps <- list_replications(fixture_doi())
    expect_output(print(reps), "Replications:")
    expect_output(print(reps), "fig_1")
  })
})

test_that("list_replications grouped returns one entry per logical group", {
  with_fixture_opts({
    groups <- list_replications(fixture_doi(), grouped = TRUE)
    expect_true(length(groups) >= 2L)
    ids <- vapply(groups, function(x) as.character(x$id), character(1))
    expect_true(all(c("fig_1", "tab_1") %in% ids))
  })
})

test_that("list_replications include pipeline filters prep steps", {
  with_fixture_opts({
    pipeline <- list_replications(fixture_doi(), include = "pipeline")
    expect_type(pipeline, "list")
  })
})

test_that("paper_article_url prefers article_url over doi.org", {
  url <- paper_article_url(
    doi = "10.1017/S0003055403000534",
    paper = list(
      article_url = paste0(
        "https://www.cambridge.org/core/journals/",
        "american-political-science-review/article/abs/",
        "ethnicity-insurgency-and-civil-war/",
        "B1D5D0E7C782483C5D7E102A61AD6605"
      )
    )
  )
  expect_match(url, "^https://www\\.cambridge\\.org/")
  expect_false(grepl("^https://doi\\.org/", url))
})

test_that("paper_article_url falls back to doi.org", {
  url <- paper_article_url(doi = "10.1177/00491241211036161")
  expect_equal(url, "https://doi.org/10.1177/00491241211036161")
})

test_that("get_code returns replication script text", {
  with_fixture_opts({
    code <- get_code(fixture_doi(), "fig_1")
    expect_type(code, "character")
    expect_true(any(nchar(code) > 10L))
  })
})

test_that("run_replication returns analysis object from fixture", {
  with_fixture_opts({
    invisible(suppressMessages(capture.output({
      obj <- run_replication(fixture_doi(), "tab_1", format = FALSE)
    })))
    expect_true(is.data.frame(obj) || is.list(obj))
  })
})

test_that("run_replication everything runs all fixture replications", {
  with_fixture_opts({
    invisible(capture.output({
      results <- run_replication(fixture_doi(), "everything")
    }))
    expect_type(results, "list")
    expect_true(length(results) >= 2L)
  })
})

test_that("check_folder_replication validates fixture study", {
  with_fixture_opts({
    study_dir <- file.path(
      getOption("replicateEverything.study_folders_root"),
      "rep-10.9999_example"
    )
    skip_if_not(dir.exists(study_dir), "fixture study repo missing")
    result <- check_folder_replication(
      study_dir,
      full_replication = FALSE,
      registry_root = getOption("replicateEverything.registry_root")
    )
    expect_s3_class(result, "folder_replication_check")
    expect_true(is.logical(result$ok))
  })
})

test_that("build_study_artifacts writes manifest for fixture study", {
  with_fixture_opts({
    study_dir <- file.path(
      getOption("replicateEverything.study_folders_root"),
      "rep-10.9999_example"
    )
    skip_if_not(dir.exists(study_dir), "fixture study repo missing")
    skip_if_not_installed("ggplot2")

    tmp <- withr::local_tempdir()
    file.copy(study_dir, tmp, recursive = TRUE)
    copy_root <- file.path(tmp, basename(study_dir))

    invisible(build_study_artifacts(
      copy_root,
      install_deps = FALSE,
      registry_root = getOption("replicateEverything.registry_root")
    ))
    manifest <- file.path(copy_root, "outputs", "manifest.json")
    expect_true(file.exists(manifest))
  })
})

test_that("prepare_folder_paper writes registry stub when checks pass", {
  with_fixture_opts({
    study_dir <- file.path(
      getOption("replicateEverything.study_folders_root"),
      "rep-10.9999_example"
    )
    skip_if_not(dir.exists(study_dir), "fixture study repo missing")

    tmp <- withr::local_tempdir()
    file.copy(study_dir, tmp, recursive = TRUE)
    copy_root <- file.path(tmp, basename(study_dir))
    dir.create(file.path(copy_root, "artifacts"), showWarnings = FALSE)
    writeLines(
      '{"version":1,"artifacts":[]}',
      file.path(copy_root, "artifacts", "manifest.json")
    )

    result <- prepare_folder_paper(
      copy_root,
      build_artifacts = FALSE,
      registry_root = getOption("replicateEverything.registry_root")
    )
    expect_s3_class(result, "folder_replication_check")
    stub <- file.path(copy_root, "registry", "replication.yml")
    if (isTRUE(result$ok)) {
      expect_true(file.exists(stub))
    }
  })
})

test_that("sync_folder_paper copies stub into registry checkout", {
  with_fixture_opts({
    study_dir <- file.path(
      getOption("replicateEverything.study_folders_root"),
      "rep-10.9999_example"
    )
    skip_if_not(dir.exists(study_dir), "fixture study repo missing")

    tmp <- withr::local_tempdir()
    reg <- file.path(tmp, "registry")
    studies <- file.path(reg, "studies")
    dir.create(studies, recursive = TRUE)
    writeLines(
      "folder,doi,title,journal,year,authors,repo",
      file.path(reg, "index.csv")
    )

    file.copy(study_dir, tmp, recursive = TRUE)
    copy_root <- file.path(tmp, basename(study_dir))
    write_folder_registry_stub(copy_root)

    synced <- sync_folder_paper(copy_root, registry_root = reg)
    expect_true(file.exists(synced$stub_path))
    expect_true(file.exists(file.path(studies, paste0(synced$folder, ".yml"))))
  })
})

test_that("run_replication language parameter resolves dual-engine entries", {
  meta <- list(
    paper = list(doi = "https://doi.org/10.1257/aer.91.5.1369", title = "Test"),
    replications = list(
      list(id = "tab_1", group = "tab_1", engine = "r", type = "table", code = "x.R"),
      list(id = "tab_1_stata", group = "tab_1", engine = "stata", type = "table", code = "x.do")
    )
  )
  r_entry <- find_replication_entry(meta, "tab_1")
  stata_entry <- find_replication_entry(meta, "tab_1", language = "stata")
  expect_equal(r_entry$id, "tab_1")
  expect_equal(stata_entry$id, "tab_1_stata")
})

test_that("save_local_shiny materializes app files", {
  tmp <- withr::local_tempdir()
  save_local_shiny(tmp)
  expect_true(file.exists(file.path(tmp, "app.R")))
  expect_true(dir.exists(file.path(tmp, "www")))
})

test_that("run_replication accepts registry handles", {
  with_fixture_opts({
    invisible(suppressMessages(capture.output({
      reps <- list_replications("fixture-paper")
    })))
    expect_true(length(reps) >= 1L)
  })
})

test_that("build_shiny_studies_cache writes schema with notes and related", {
  tmp <- withr::local_tempdir()
  studies_dir <- file.path(tmp, "studies")
  dir.create(studies_dir, recursive = TRUE)

  yaml::write_yaml(
    list(
      paper = list(
        doi = "https://doi.org/10.9999/example",
        title = "Example study",
        journal = "Test Journal",
        year = 2024,
        authors = "Lead, Author, Second, Author",
        article_url = "https://example.org/article",
        source_repository = "https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/EXAMPLE"
      ),
      repo = "org/example-study",
      maintainer = list(name = "Maintainer", email = "m@example.org"),
      collections = list("APSR", "IPI"),
      languages = list("r", "stata"),
      notes = list(data_unavailable = TRUE, missing_engine = FALSE)
    ),
    file.path(studies_dir, "10.9999_example.yml")
  )
  yaml::write_yaml(
    list(
      paper = list(
        study_handle = "reanalysis-example",
        title = "Reanalysis of example",
        year = "2026a",
        authors = "Team, Replicate",
        related = list(list(doi = "10.9999/example")),
        extends = list(doi = "10.9999/example", repo = "org/example-study")
      ),
      repo = "org/reanalysis-example",
      maintainer = list(name = "Maintainer", email = "m@example.org"),
      collections = list("IPI"),
      languages = list("r", "mathematica"),
      notes = list(data_unavailable = FALSE, missing_engine = TRUE)
    ),
    file.path(studies_dir, "reanalysis-example.yml")
  )

  built <- build_registry_index(tmp)
  expect_true(file.exists(built$index_path))
  expect_true(file.exists(built$shiny_studies_path))
  expect_equal(
    normalizePath(built$shiny_studies_path, winslash = "/", mustWork = FALSE),
    normalizePath(file.path(tmp, "shiny_studies.json"), winslash = "/", mustWork = FALSE)
  )

  cache <- load_shiny_studies_cache(tmp, force = TRUE)
  expect_equal(cache$n, 2L)
  expect_equal(cache$schema_version, 1L)
  expect_true(length(cache$studies) == 2L)

  keys <- vapply(cache$studies, function(s) s$key, character(1))
  expect_true("10.9999/example" %in% keys)
  expect_true("reanalysis-example" %in% keys)

  base <- cache$studies[[which(keys == "10.9999/example")]]
  expect_true(isTRUE(base$notes$data_unavailable))
  expect_false(isTRUE(base$notes$missing_engine))
  expect_equal(unlist(base$collections), c("APSR", "IPI"))
  expect_true(isTRUE(base$engines$r) && isTRUE(base$engines$stata))
  expect_true(nzchar(base$citation_label))
  expect_equal(base$study_url, "https://github.com/org/example-study")
  expect_equal(base$article_url, "https://example.org/article")
  expect_equal(
    base$source_repository,
    "https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/EXAMPLE"
  )
  expect_equal(base$source_repository_kind, "dataverse")
  expect_true(length(base$related_downstream) >= 1L)
  expect_equal(base$related_downstream[[1]]$key, "reanalysis-example")

  re <- cache$studies[[which(keys == "reanalysis-example")]]
  expect_true(isTRUE(re$notes$missing_engine))
  expect_true(isTRUE(re$engines$mathematica))
  expect_true(length(re$related_upstream) >= 1L)
  expect_equal(re$related_upstream[[1]]$key, "10.9999/example")

  filtered <- studies_table_data(cache, collection = "APSR")
  expect_equal(length(filtered), 1L)
  expect_equal(filtered[[1]]$key, "10.9999/example")

  all_rows <- studies_table_data(cache, collection = "__all_studies__")
  expect_equal(length(all_rows), 2L)

  # Session memo: second load with same mtime returns identical object
  again <- load_shiny_studies_cache(tmp)
  expect_identical(again$mtime, cache$mtime)
  expect_equal(again$n, cache$n)
})

test_that("registry stub sync bakes notes from study yaml gaps", {
  tmp <- withr::local_tempdir()
  study <- file.path(tmp, "rep-gap")
  reg <- file.path(tmp, "registry")
  dir.create(study, recursive = TRUE)
  dir.create(file.path(reg, "studies"), recursive = TRUE)
  writeLines(
    "folder,doi,title,journal,year,authors,repo",
    file.path(reg, "index.csv")
  )
  meta <- list(
    paper = list(
      study_handle = "rep-gap",
      title = "Gap study",
      year = 2026,
      authors = "A Author"
    ),
    maintainer = list(name = "Test", email = "t@example.org"),
    collections = list("IPI"),
    languages = list("stata"),
    repo = "org/rep-gap",
    steps = list(
      list(
        id = "tab_1",
        type = "table",
        incomplete = TRUE,
        data_unavailable = "proprietary",
        code = "code/tab_1.do",
        outputs = list("outputs/tab_1.html")
      )
    )
  )
  yaml::write_yaml(meta, file.path(study, "replication.yml"))

  synced <- sync_study_to_registry(study, registry_root = reg)
  stub <- yaml::read_yaml(synced$stub_path)
  expect_true(isTRUE(stub$notes$data_unavailable))
})

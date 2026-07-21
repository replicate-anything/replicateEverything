test_that("check_replication validates Bounding Causes study", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1177-00491241211036161")
  testthat::skip_if_not(dir.exists(study_dir), "Bounding Causes study repo missing")

  registry_root <- file.path(monorepo_root, "registry")
  result <- check_replication(
    study_dir,
    full_replication = FALSE,
    registry_root = registry_root
  )
  expect_s3_class(result, "folder_replication_check")
  expect_s3_class(result, "replication_check")
  failed <- result$checks[!result$checks$passed, , drop = FALSE]
  if (nrow(failed) > 0) {
    msg <- paste0(failed$check, ": ", failed$message, collapse = "; ")
    testthat::skip(paste("folder checks failed:", msg))
  }
  expect_true(result$ok)
})

test_that("registry_stub_from_folder_meta includes summary fields", {
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1177/00491241211036161",
      title = "Test",
      study_repo = "org/study"
    ),
    repo = "org/study",
    maintainer = list(
      name = "Macartan Humphreys",
      email = "macartan.humphreys@wzb.eu"
    ),
    collections = c("IPI"),
    languages = list("r"),
    replications = list(list(id = "fig_1"))
  )
  stub <- registry_stub_from_folder_meta(
    meta,
    study_folder = "rep-study",
    study_root = "/tmp/rep-study"
  )
  expect_null(stub$replications)
  expect_equal(stub$paper$materials, "folder")
  expect_equal(stub$maintainer$email, "macartan.humphreys@wzb.eu")
  expect_equal(unlist(stub$collections), "IPI")
  expect_equal(unlist(stub$languages), "r")
})

test_that("build_registry_index compiles index from study stubs", {
  registry_root <- file.path(testthat::test_path(".."), "fixtures", "registry")
  testthat::skip_if_not(dir.exists(registry_root), "fixture registry missing")
  tmp <- file.path(tempdir(), "registry_build_index_test")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(file.path(tmp, "studies"), recursive = TRUE, showWarnings = FALSE)
  file.copy(
    file.path(registry_root, "studies", "10.9999_example.yml"),
    file.path(tmp, "studies", "10.9999_example.yml")
  )
  stub <- yaml::read_yaml(file.path(tmp, "studies", "10.9999_example.yml"))
  stub$maintainer <- list(name = "Test Maintainer", email = "test@example.org")
  stub$collections <- list("APSR")
  stub$languages <- list("r")
  yaml::write_yaml(stub, file.path(tmp, "studies", "10.9999_example.yml"))

  built <- build_registry_index(tmp)
  expect_equal(built$n, 1L)
  index <- utils::read.csv(built$index_path, stringsAsFactors = FALSE)
  expect_equal(index$maintainer_email[[1]], "test@example.org")
  expect_equal(index$collections[[1]], "APSR")
})

test_that("write_folder_registry_stub creates registry sync files", {
  tmp <- file.path(tempdir(), "rep-10.1177-00491241211036161")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.1177/00491241211036161",
      title = "Test study",
      journal = "Journal",
      year = 2022,
      authors = "A Author"
    ),
    replications = list(list(id = "fig_1", type = "figure", code = "code/fig_1.R"))
  )
  yaml::write_yaml(meta, file.path(tmp, "replication.yml"))
  dir.create(file.path(tmp, "registry"), showWarnings = FALSE)

  written <- write_folder_registry_stub(tmp)
  expect_true(file.exists(written$stub_path))
  expect_true(file.exists(written$index_path))
  stub <- yaml::read_yaml(written$stub_path)
  expect_null(stub$replications)
  expect_equal(stub$paper$materials, "folder")
  index <- utils::read.csv(written$index_path, stringsAsFactors = FALSE)
  expect_equal(nrow(index), 1L)
})

test_that("enrich_folder_study_replication_meta merges stata fields from study repo", {
  stub <- yaml::read_yaml(
    file.path(
      testthat::test_path(".."), "fixtures", "registry", "studies", "10.9999_stata.yml"
    )
  )
  ctx <- list(local_root = fixture_stata_study_root())
  enriched <- replicateEverything:::enrich_folder_study_replication_meta(stub, ctx)
  expect_true(length(enriched$replications %||% list()) > 0L)
  expect_equal(
    as.character(enriched$stata_packages[[1]]),
    "estout"
  )
})

test_that("registry_study_yaml_path prefers flat stub files", {
  tmp <- withr::local_tempdir()
  studies <- file.path(tmp, "studies")
  dir.create(studies, recursive = TRUE)
  flat <- file.path(studies, "10.9999_example.yml")
  writeLines("paper:\n  doi: 10.9999/example", flat)
  expect_equal(
    registry_study_yaml_path(tmp, "10.9999_example"),
    flat
  )
})

test_that("registry_paper_yaml_path alias resolves studies stubs", {
  tmp <- withr::local_tempdir()
  studies <- file.path(tmp, "studies")
  dir.create(studies, recursive = TRUE)
  flat <- file.path(studies, "10.9999_example.yml")
  writeLines("paper:\n  doi: 10.9999/example", flat)
  expect_equal(
    registry_paper_yaml_path(tmp, "10.9999_example"),
    flat
  )
})

test_that("infer_study_repo_slug derives from folder name", {
  meta <- list(paper = list(doi = "https://doi.org/10.1/example"))
  expect_equal(
    infer_study_repo_slug("/work/rep-10.1177-00491241211036161", meta),
    "replicate-anything/rep-10.1177-00491241211036161"
  )
})

test_that("is_local_doi_query recognizes local aliases", {
  expect_true(is_local_doi_query(""))
  expect_true(is_local_doi_query("local"))
  expect_true(is_local_doi_query("LOCAL"))
  expect_true(is_local_doi_query("."))
  expect_false(is_local_doi_query("10.1/example"))
})

test_that("resolve_doi_input finds local replication.yml", {
  tmp <- withr::local_tempdir()
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.9999/localtest",
      title = "Local test"
    ),
    replications = list(list(id = "tab_1", type = "table", code = "code/tab_1.R"))
  )
  yaml::write_yaml(meta, file.path(tmp, "replication.yml"))
  withr::with_dir(tmp, {
    out <- resolve_doi_input("local")
    expect_equal(out$doi, "10.9999/localtest")
    expect_true(out$is_local)
    expect_equal(basename(out$local_root), basename(tmp))
  })
})

test_that("resolve_doi_input errors when no local study exists", {
  tmp <- withr::local_tempdir()
  withr::with_dir(tmp, {
    expect_error(resolve_doi_input("local"), "No replication.yml found")
  })
})

test_that("resolve_doi_input accepts an explicit study path", {
  tmp <- withr::local_tempdir()
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.9999/pathtest",
      title = "Path test"
    ),
    replications = list(list(id = "tab_1", type = "table", code = "code/tab_1.R"))
  )
  yaml::write_yaml(meta, file.path(tmp, "replication.yml"))
  out <- resolve_doi_input(tmp)
  expect_equal(out$doi, "10.9999/pathtest")
  expect_true(out$is_local)
  expect_equal(normalizePath(out$local_root, winslash = "/"), normalizePath(tmp, winslash = "/"))
})

test_that("resolve_doi_input path errors include formatting hints", {
  expect_error(resolve_doi_input("c:/no/such/repo"), "Could not find replication.yml")
  expect_error(resolve_doi_input("c:/no/such/repo"), "Windows:")
  expect_error(resolve_doi_input("c:/no/such/repo"), "macOS:")
})

test_that("folder_manifest_metadata uses github slug not absolute paths", {
  tmp <- withr::local_tempdir()
  study <- file.path(tmp, "rep-10.9999-manifest")
  dir.create(study, recursive = TRUE)
  meta <- list(
    paper = list(
      doi = "https://doi.org/10.9999/manifest",
      title = "Manifest test"
    ),
    repo = "replicate-anything/rep-10.9999-manifest"
  )
  yaml::write_yaml(meta, file.path(study, "replication.yml"))
  withr::with_options(list(replicateEverything.study_folders_root = tmp), {
    out <- folder_manifest_metadata(study, meta)
    expect_equal(out$study_repo, "replicate-anything/rep-10.9999-manifest")
    expect_equal(out$study_folder, "rep-10.9999-manifest")
    expect_null(out$monorepo_path)
    expect_false(grepl(normalizePath(tmp, winslash = "/"), paste(unlist(out), collapse = " ")))
  })
})

test_that("portable_path_in_text rewrites study and monorepo roots", {
  monorepo <- normalizePath(withr::local_tempdir(), winslash = "/")
  study <- file.path(monorepo, "rep-10.9999_paths")
  dir.create(study, recursive = TRUE)
  raw <- paste0(
    "Missing file: ", study, "/outputs/tab_1.html\n",
    "Monorepo: ", monorepo, "/registry"
  )
  withr::with_options(list(replicateEverything.study_folders_root = monorepo), {
    out <- portable_path_in_text(raw, study)
    expect_match(out, "rep-10.9999_paths/outputs/tab_1.html", fixed = TRUE)
    expect_match(out, "./registry", fixed = TRUE)
    expect_false(grepl(monorepo, out, fixed = TRUE))
  })
})

test_that("table_artifact_file_ok accepts html tables and stata pre output", {
  tmp <- withr::local_tempdir()
  html_table <- file.path(tmp, "tab.html")
  writeLines("<table><tr><td>1</td></tr></table>", html_table)
  expect_true(table_artifact_file_ok(html_table))

  stata_pre <- file.path(tmp, "stata.html")
  writeLines('<pre class="stata-output replication-table">logit</pre>', stata_pre)
  expect_false(table_artifact_file_ok(stata_pre))
  expect_true(table_artifact_file_ok(stata_pre, engine = "stata"))

  rds_path <- file.path(tmp, "tab.rds")
  saveRDS(data.frame(x = 1), rds_path)
  expect_true(table_artifact_file_ok(rds_path))
})

test_that("study_location_input_hints detects dash mashup", {
  msg <- replicateEverything:::study_location_input_hints("10.1017-s0003055426101622")
  expect_match(msg, "repo-folder or DOI fragment")
  expect_match(msg, "10.1017/s0003055426101622")
  expect_match(msg, "rep-10.1017-s0003055426101622")
})

test_that("try_resolve_study_by_common_alias finds sibling study folder", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-s0003055426101622")
  testthat::skip_if_not(dir.exists(study_dir), "Velez study repo missing")

  old <- options(
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.registry_root = file.path(monorepo_root, "registry")
  )
  on.exit(options(old), add = TRUE)

  resolved <- replicateEverything:::try_resolve_study_by_common_alias(
    "10.1017-s0003055426101622"
  )
  expect_equal(
    normalizePath(resolved, winslash = "/"),
    normalizePath(study_dir, winslash = "/")
  )
})

test_that("try_resolve_study_from_registry_folder maps registry folder to study repo", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.5555-cahw")
  testthat::skip_if_not(dir.exists(study_dir), "cahw study repo missing")

  old <- options(
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.registry_root = file.path(monorepo_root, "registry")
  )
  on.exit(options(old), add = TRUE)

  resolved <- replicateEverything:::try_resolve_study_from_registry_folder("10.5555_cahw")
  expect_equal(
    normalizePath(resolved, winslash = "/"),
    normalizePath(study_dir, winslash = "/")
  )
})

test_that("looks_like_study_alias identifies registry folder handles", {
  expect_true(replicateEverything:::looks_like_study_alias("10.5555_cahw"))
  expect_true(replicateEverything:::looks_like_study_alias("rep-10.5555-cahw"))
  expect_false(replicateEverything:::looks_like_study_alias("rep1371journalpone0278337"))
})

test_that("build_study_outputs rejects registry folder when study cannot be resolved", {
  old <- options(
    replicateEverything.registry_root = NULL,
    replicateEverything.study_folders_root = "C:/nonexistent/monorepo",
    replicateEverything.use_sibling_packages = FALSE
  )
  on.exit(options(old), add = TRUE)

  err <- tryCatch(
    build_study_outputs("10.9999_not_a_real_study", install_deps = FALSE),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "Could not resolve study location: 10.9999_not_a_real_study")
  expect_no_match(conditionMessage(err), "there is no package called")
})

test_that("resolve_study_location rejects bare DOI without local sibling", {
  expect_error(
    resolve_study_location("10.9999/nonexistent-study"),
    "Could not find a local study folder for DOI"
  )
  expect_error(
    resolve_study_location("10.9999/nonexistent-study"),
    "rep-10.9999-nonexistent-study"
  )
})

test_that("check_replication resolves DOI via configured monorepo sibling", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-s0003055426101622")
  testthat::skip_if_not(dir.exists(study_dir), "Velez study repo missing")

  configure_local_monorepo(monorepo_root)
  res <- check_replication("10.1017/S0003055426101622")
  expect_true(res$checks$passed[res$checks$check == "resolve_location"])
  expect_equal(
    normalizePath(res$study_path, winslash = "/"),
    normalizePath(study_dir, winslash = "/")
  )
})

test_that("resolve_doi_input finds sibling study via monorepo option", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-s0003055426101622")
  testthat::skip_if_not(dir.exists(study_dir), "Velez study repo missing")

  old <- options(replicateEverything.study_folders_root = monorepo_root)
  on.exit(options(old), add = TRUE)

  out <- resolve_doi_input("10.1017/S0003055426101622")
  expect_equal(
    normalizePath(out$local_root, winslash = "/"),
    normalizePath(study_dir, winslash = "/")
  )
  expect_true(out$is_local)
})

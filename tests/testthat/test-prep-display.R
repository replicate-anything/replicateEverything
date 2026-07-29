test_that("preview_data_file returns head for RDS data frames", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  df <- data.frame(a = 1:10, b = letters[1:10])
  saveRDS(df, tmp)

  preview <- replicateEverything:::preview_data_file(tmp)
  expect_s3_class(preview, "data.frame")
  expect_equal(nrow(preview), 6L)
  expect_equal(ncol(preview), 2L)
})

test_that("resolve_prep_display_object promotes RDS path preview", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  df <- data.frame(x = 1:8, y = letters[1:8])
  saveRDS(df, tmp)

  preview <- structure(
    list(path = tmp, note = "RDS output: example.rds"),
    class = "prep_output_preview"
  )
  resolved <- replicateEverything:::resolve_prep_display_object(preview)
  expect_s3_class(resolved, "data.frame")
  expect_equal(nrow(resolved), 6L)
})

test_that("resolve_prep_display_object unwraps replication_result data frames", {
  df <- data.frame(col = 1:12)
  result <- structure(
    list(object = df, output_path = "/tmp/out.rds"),
    class = "replication_result"
  )
  resolved <- replicateEverything:::resolve_prep_display_object(result)
  expect_s3_class(resolved, "data.frame")
  expect_equal(nrow(resolved), 6L)
})

test_that("prep_step_display_caption prefers path_note and truncates", {
  prep <- list(
    id = "analysis_data",
    label = "Analysis data",
    description = "Rename lpopl1 and recode onset indicators for analysis"
  )
  expect_equal(
    replicateEverything:::prep_step_display_caption(prep),
    "`Analysis data` step (Rename lpopl1 and recode onset indicators for analysis)"
  )

  long <- list(
    id = "cost_curve_data_r",
    label = "LBD cost-curve data (R translation)",
    path_note = "R is a translation of the original Mathematica LBD kernel",
    description = paste(rep("word", 80L), collapse = " ")
  )
  cap <- replicateEverything:::prep_step_display_caption(long)
  expect_match(cap, "R is a translation", fixed = TRUE)
  expect_false(grepl("word word word word word", cap, fixed = TRUE))
})

test_that("summarize_prep_transform_sink invents a useful .done summary", {
  root <- tempfile("prep-sink-")
  dir.create(file.path(root, "outputs", "clean_data"), recursive = TRUE)
  dir.create(file.path(root, "data", "1_assumptions", "evs"), recursive = TRUE)
  writeLines(
    "clean_data completed 28 Jul 2026 20:02:24",
    file.path(root, "outputs", "clean_data", ".done")
  )
  write.csv(
    data.frame(a = 1:3),
    file.path(root, "data", "1_assumptions", "evs", "x.csv"),
    row.names = FALSE
  )

  prep <- list(
    id = "clean_data",
    label = "Clean input data",
    description = "Builds battery/EV inputs",
    outputs = list("outputs/clean_data/.done"),
    products = list("data/1_assumptions/evs"),
    inputs = list("data/1_assumptions/evs")
  )
  meta <- list(steps = list(prep))
  ctx <- list(local_path = root)
  path <- file.path(root, "outputs", "clean_data", ".done")
  summary <- replicateEverything:::summarize_prep_transform_sink(
    meta, ctx, prep, path = path
  )
  expect_s3_class(summary, "prep_transform_summary")
  expect_match(summary$note, "Clean input data", fixed = TRUE)
  expect_match(summary$note, "Products:", fixed = TRUE)
  expect_match(summary$note, "data/1_assumptions/evs", fixed = TRUE)
  expect_false(identical(trimws(summary$note), "clean_data completed 28 Jul 2026 20:02:24"))
})

test_that("is_prep_marker_sink detects .done", {
  expect_true(replicateEverything:::is_prep_marker_sink("/tmp/outputs/x/.done"))
  expect_false(replicateEverything:::is_prep_marker_sink("/tmp/out.csv"))
})

test_that("study_artifact_rel_candidates keeps declared prep sinks over html/png", {
  done_rep <- list(
    id = "clean_data",
    type = "transform",
    outputs = list("outputs/clean_data/.done")
  )
  cands <- study_artifact_rel_candidates(done_rep)
  expect_identical(cands[[1]], "outputs/clean_data/.done")
  expect_false(any(grepl("clean_data\\.html$", cands)))
  expect_false(any(grepl("clean_data\\.png$", cands)))

  csv_rep <- list(
    id = "cost_curve_data_r",
    type = "transform",
    outputs = list("outputs/cost_curve_data_r/lbd_cost_curve.csv")
  )
  cands2 <- study_artifact_rel_candidates(csv_rep)
  expect_identical(cands2[[1]], "outputs/cost_curve_data_r/lbd_cost_curve.csv")
  expect_true(
    "outputs/cost_curve_data_r/lbd_cost_curve.csv" %in%
      study_declared_displayable_rels(csv_rep)
  )
})

test_that("load_artifact_panels delegates prep steps to load_artifact", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1257-aer.20250166")
  testthat::skip_if_not(dir.exists(study_dir), "Hahn study repo missing")
  testthat::skip_if_not(
    file.exists(file.path(study_dir, "outputs", "clean_data", ".done")),
    "clean_data .done missing"
  )

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  doi <- "10.1257/aer.20250166"
  folder <- "rep-10.1257-aer.20250166"

  cands <- artifact_lookup_candidates(doi, "clean_data", folder = folder)
  expect_true(any(grepl("clean_data[/\\\\]\\.done$", cands) | grepl("\\.done$", cands)))
  expect_false(any(grepl("clean_data\\.html$", cands)))

  panels <- load_artifact_panels(doi, "clean_data", folder = folder)
  expect_false(artifact_content_missing(panels))
  expect_s3_class(panels, "prep_transform_summary")

  disp <- load_replication_for_display(
    doi, "clean_data",
    folder = folder, prefer = "artifact", fallback_live = FALSE
  )
  expect_true(disp$ok)
  expect_equal(disp$source, "artifact")

  dta_disp <- load_replication_for_display(
    doi, "compute_mvpf_main",
    folder = folder, prefer = "artifact", fallback_live = FALSE
  )
  expect_true(dta_disp$ok)
  expect_s3_class(dta_disp$value, "data.frame")
})

test_that("load_artifact returns data frame preview for Fearon analysis_data", {
  monorepo_root <- normalizePath(
    file.path(testthat::test_path(".."), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
  study_dir <- file.path(monorepo_root, "rep-10.1017-S0003055403000534")
  rds_path <- file.path(study_dir, "outputs", "analysis_data.rds")
  testthat::skip_if_not(dir.exists(study_dir), "Fearon study repo missing")
  testthat::skip_if_not(file.exists(rds_path), "analysis_data.rds missing (run prep step first)")

  withr::local_options(list(
    replicateEverything.registry_root = file.path(monorepo_root, "registry"),
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.use_sibling_packages = TRUE
  ))

  loaded <- load_artifact("10.1017/S0003055403000534", "analysis_data", folder = basename(study_dir))
  expect_s3_class(loaded, "data.frame")
  expect_lte(nrow(loaded), 6L)
})

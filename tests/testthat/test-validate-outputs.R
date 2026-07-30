test_that("default artifact path uses png for figures", {
  rep <- list(type = "figure")
  expect_equal(default_artifact_path(rep, "fig_1"), "outputs/fig_1.png")
})

test_that("default artifact path uses html when format is specified", {
  rep <- list(type = "table", format = "format_tab_1")
  expect_equal(default_artifact_path(rep, "tab_1"), "outputs/tab_1.html")
})

test_that("default artifact path uses html for tables", {
  rep <- list(type = "table")
  expect_equal(default_artifact_path(rep, "tab_1"), "outputs/tab_1.html")
})

test_that("study_artifact_rel_path uses replication.yml outputs when set", {
  rep <- list(
    id = "tab_2",
    type = "table",
    outputs = list("outputs/tab_2.html")
  )
  expect_equal(study_artifact_rel_path(rep), "outputs/tab_2.html")
})

test_that("study_artifact_rel_path falls back to the type-based default", {
  expect_equal(
    study_artifact_rel_path(list(id = "fig_1", type = "figure")),
    "outputs/fig_1.png"
  )
  expect_equal(
    study_artifact_rel_path(list(id = "tab_1", type = "table")),
    "outputs/tab_1.html"
  )
})

test_that("study_declared_displayable_rels omits type fallbacks", {
  rep <- list(
    id = "fig_2",
    type = "figure",
    outputs = list(
      "outputs/waterfall_a.png",
      "outputs/panel_b.png",
      "outputs/notes.txt"
    )
  )
  expect_identical(
    study_declared_displayable_rels(rep),
    c("outputs/waterfall_a.png", "outputs/panel_b.png")
  )
  cands <- study_artifact_rel_candidates(rep)
  expect_true("outputs/fig_2.png" %in% cands)
  expect_identical(study_artifact_rel_path(rep), "outputs/waterfall_a.png")
})

test_that("format_xlsx_preview_cell rounds numerics to 3 decimals", {
  expect_identical(format_xlsx_preview_cell(1.23456), "1.235")
  expect_identical(format_xlsx_preview_cell(2), "2.000")
  expect_identical(format_xlsx_preview_cell("3.14159"), "3.142")
  expect_identical(format_xlsx_preview_cell("Policy A"), "Policy A")
  expect_identical(format_xlsx_preview_cell(NA_real_), "")
  # Hahn tab_2 Excel text cells / binary float artifacts (must not pass through).
  expect_identical(format_xlsx_preview_cell("6.2399425510000004"), "6.240")
  expect_identical(format_xlsx_preview_cell("-113.1814499"), "-113.181")
  expect_identical(format_xlsx_preview_cell(6.2399425510000004), "6.240")
  expect_identical(format_xlsx_preview_cell(list("6.2399425510000004")), "6.240")
})

test_that("format_xlsx_preview_df rounds numeric columns and keeps text", {
  out <- format_xlsx_preview_df(
    as.data.frame(
      list(V1 = c(1.23456, NA_real_), V2 = c("x", "")),
      stringsAsFactors = FALSE
    )
  )
  expect_identical(out[[1]][[1]], "1.235")
  expect_identical(out[[2]][[1]], "x")

  # Character columns with float-artifact strings (Hahn tab_2 TABLE sheet).
  hahnish <- as.data.frame(
    list(
      V1 = c("Wind Production Credits", "note"),
      V2 = c("6.2399425510000004", "keep"),
      V3 = c("-113.1814499", "")
    ),
    stringsAsFactors = FALSE
  )
  out2 <- format_xlsx_preview_df(hahnish)
  expect_identical(out2[[1]][[1]], "Wind Production Credits")
  expect_identical(out2[[2]][[1]], "6.240")
  expect_identical(out2[[3]][[1]], "-113.181")
  expect_identical(out2[[2]][[2]], "keep")
})

test_that("xlsx_preview_sheet_names prefers data_export over presentation sheets", {
  # Hahn-style: TABLE holds stale formula cache; data_export has live numbers.
  expect_identical(
    xlsx_preview_sheet_names(c("TABLE", "data_export")),
    "data_export"
  )
  expect_identical(
    xlsx_preview_sheet_names(c("data_export", "TABLE")),
    "data_export"
  )
  expect_identical(
    xlsx_preview_sheet_names(c("TABLE", "Metadata", "readme")),
    "TABLE"
  )
  expect_identical(
    xlsx_preview_sheet_names(c("Sheet1", "Sheet2")),
    c("Sheet1", "Sheet2")
  )
  expect_identical(xlsx_preview_sheet_names(character(0)), character(0))
})

test_that("get_artifact_paths returns all declared figure panels that exist", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555-panels")
  dir.create(file.path(study_dir, "outputs"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/panels",
      "steps:",
      "  - id: fig_2",
      "    type: figure",
      "    code: code/fig_2.R",
      "    outputs:",
      "      - outputs/panel_a.png",
      "      - outputs/panel_b.png"
    ),
    file.path(study_dir, "replication.yml")
  )
  writeBin(as.raw(1:200), file.path(study_dir, "outputs", "panel_a.png"))
  writeBin(as.raw(1:200), file.path(study_dir, "outputs", "panel_b.png"))
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/panels",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555-panels",
      "  study_folder: rep-10.5555-panels",
      "repo: replicate-anything/rep-10.5555-panels"
    ),
    file.path(local_root, "studies", "10.5555_panels.yml")
  )
  local_index <- data.frame(
    folder = "10.5555_panels",
    doi = "10.5555/panels",
    title = "Panels test",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/rep-10.5555-panels",
    stringsAsFactors = FALSE
  )

  withr::with_options(
    list(
      replicateEverything.registry_root = local_root,
      replicateEverything.study_folders_root = local_root,
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.index = local_index
    ),
    {
      rm(list = ls(envir = .replication_meta_cache), envir = .replication_meta_cache)
      paths <- get_artifact_paths("10.5555/panels", "fig_2", folder = "rep-10.5555-panels")
      expect_length(paths, 2L)
      expect_true(all(basename(paths) %in% c("panel_a.png", "panel_b.png")))
      panels <- load_artifact_panels("10.5555/panels", "fig_2", folder = "rep-10.5555-panels")
      expect_true(is.character(panels))
      expect_length(panels, 2L)
      # Primary single-path helper still returns the first panel only.
      expect_identical(
        basename(get_artifact_path("10.5555/panels", "fig_2", folder = "rep-10.5555-panels")),
        "panel_a.png"
      )
    }
  )
})

test_that("study_artifact_rel_candidates includes Excel table sinks", {
  rep <- list(
    id = "tab_1",
    type = "table",
    outputs = list("outputs/Table1_scc193_main.xlsx")
  )
  cands <- study_artifact_rel_candidates(rep)
  expect_identical(cands[[1]], "outputs/Table1_scc193_main.xlsx")
  expect_identical(study_artifact_rel_path(rep), "outputs/Table1_scc193_main.xlsx")
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  zz <- file(tmp, "wb")
  writeBin(as.raw(rep(as.raw(1L), 200L)), zz)
  close(zz)
  expect_true(table_artifact_file_ok(tmp))
})

test_that("read_artifact_file returns path for xlsx sinks", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  zz <- file(tmp, "wb")
  writeBin(as.raw(rep(as.raw(2L), 120L)), zz)
  close(zz)
  expect_identical(read_artifact_file(tmp, "xlsx"), tmp)
})

test_that("validate_outputs prints a short PASS report", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555-print")
  dir.create(file.path(study_dir, "outputs"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/print",
      "steps:",
      "  - id: fig_1",
      "    type: figure",
      "    code: code/fig_1.R",
      "    outputs:",
      "      - outputs/fig_1.png"
    ),
    file.path(study_dir, "replication.yml")
  )
  writeBin(as.raw(1:200), file.path(study_dir, "outputs", "fig_1.png"))
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/print",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555-print",
      "  study_folder: rep-10.5555-print",
      "repo: replicate-anything/rep-10.5555-print"
    ),
    file.path(local_root, "studies", "10.5555_print.yml")
  )
  local_index <- data.frame(
    folder = "10.5555_print",
    doi = "10.5555/print",
    title = "Print test",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/rep-10.5555-print",
    stringsAsFactors = FALSE
  )
  withr::with_options(
    list(
      replicateEverything.registry_root = local_root,
      replicateEverything.study_folders_root = local_root,
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.index = local_index
    ),
    {
      rm(list = ls(envir = .replication_meta_cache), envir = .replication_meta_cache)
      out <- capture.output({
        res <- validate_outputs(doi = "10.5555/print", what = "fig_1")
        print(res)
      })
      text <- paste(out, collapse = "\n")
      expect_true(inherits(res, "validate_outputs_result"))
      expect_true(isTRUE(res$ok))
      expect_match(text, "PASS")
      expect_match(text, "fig_1")
      expect_match(text, "output validation")
      # Unassigned call auto-prints via the S3 print method
      bare <- paste(capture.output(validate_outputs(doi = "10.5555/print", what = "fig_1")), collapse = "\n")
      expect_match(bare, "PASS - output validation")
      expect_match(bare, "fig_1")
    }
  )
})

test_that("get_artifact_path resolves figure png under local folder-backed study", {
  local_root <- withr::local_tempdir()
  study_dir <- file.path(local_root, "rep-10.5555-test")
  dir.create(file.path(study_dir, "outputs"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/test",
      "steps:",
      "  - id: fig_1",
      "    type: figure",
      "    code: code/fig_1.R",
      "    outputs:",
      "      - outputs/fig_1.png"
    ),
    file.path(study_dir, "replication.yml")
  )
  writeBin(as.raw(1:200), file.path(study_dir, "outputs", "fig_1.png"))
  dir.create(file.path(local_root, "studies"), recursive = TRUE)
  writeLines(
    c(
      "paper:",
      "  doi: 10.5555/test",
      "  materials: folder",
      "  study_repo: replicate-anything/rep-10.5555-test",
      "  study_folder: rep-10.5555-test",
      "repo: replicate-anything/rep-10.5555-test"
    ),
    file.path(local_root, "studies", "10.5555_test.yml")
  )
  local_index <- data.frame(
    folder = "10.5555_test",
    doi = "10.5555/test",
    title = "Test",
    journal = "",
    year = 2026,
    authors = "A",
    repo = "replicate-anything/rep-10.5555-test",
    stringsAsFactors = FALSE
  )
  withr::with_options(
    list(
      replicateEverything.registry_root = local_root,
      replicateEverything.study_folders_root = local_root,
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.index = local_index
    ),
    {
      rm(list = ls(envir = .replication_meta_cache), envir = .replication_meta_cache)
      path <- get_artifact_path("10.5555/test", "fig_1")
      expect_true(file.exists(path))
      expect_true(artifact_available("10.5555/test", "fig_1"))
    }
  )
})

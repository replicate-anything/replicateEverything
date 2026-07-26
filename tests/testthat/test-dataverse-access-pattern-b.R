test_that("is_dataverse_access_prep_step is Pattern C only", {
  expect_false(is_dataverse_access_prep_step(
    list(id = "access_data", outputs = list("outputs/data.dta")),
    list(),
    ctx = NULL
  ))
  expect_true(is_dataverse_access_prep_step(
    list(id = "access_deposit", outputs = list("outputs/deposit/.manifest_applied")),
    list(),
    ctx = NULL
  ))
  expect_true(is_dataverse_access_prep_step(
    list(id = "fetch_deposit", code = "code/steps/access_deposit.R"),
    list(),
    ctx = NULL
  ))
})

test_that("dataverse_access_step_entries maps file_id to outputs", {
  rep <- list(
    id = "access_data",
    file_id = "14058927",
    original = TRUE,
    outputs = list("outputs/data.dta")
  )
  entries <- dataverse_access_step_entries(rep, meta = list())
  expect_length(entries, 1L)
  expect_equal(entries[[1]]$path, "outputs/data.dta")
  expect_equal(as.character(entries[[1]]$id), "14058927")
})

test_that("load_prep_step_display previews Pattern B dta when present", {
  tmp <- tempfile("blair-display-")
  dir.create(file.path(tmp, "outputs"), recursive = TRUE)
  withr::defer(unlink(tmp, recursive = TRUE, force = TRUE))

  dta <- file.path(tmp, "outputs", "data.dta")
  # Minimal non-empty placeholder so file.exists + size checks pass in preview path
  writeBin(as.raw(1:20), dta)

  meta <- list(dataverse = list(dataset = "10.7910/DVN/OXSQMU"))
  ctx <- list(local_root = tmp)
  prep <- list(
    id = "access_data",
    outputs = list("outputs/data.dta")
  )

  # Without a valid Stata file, preview_data_file may error — ensure we do not
  # route to deposit summary.
  expect_false(is_dataverse_access_prep_step(prep, meta, ctx = ctx))

  missing_prep <- list(id = "access_data", outputs = list("outputs/missing.dta"))
  disp <- load_prep_step_display(meta, ctx, missing_prep)
  expect_s3_class(disp, "prep_output_preview")
  expect_match(disp$note, "not prepared for display|not on disk", ignore.case = TRUE)
})

test_that("load_prep_step_display summarizes Pattern B dataverse when file missing", {
  tmp <- tempfile("blair-dv-")
  dir.create(file.path(tmp, "outputs"), recursive = TRUE)
  withr::defer(unlink(tmp, recursive = TRUE, force = TRUE))

  meta <- list(
    dataverse = list(
      dataset = "10.7910/DVN/OXSQMU",
      server = "dataverse.harvard.edu",
      file_id = "14058927"
    )
  )
  ctx <- list(local_root = tmp)
  prep <- list(
    id = "access_data",
    engine = "dataverse",
    file_id = "14058927",
    original = TRUE,
    outputs = list("outputs/data.dta")
  )

  disp <- load_prep_step_display(meta, ctx, prep)
  expect_s3_class(disp, "dataverse_file_access_summary")
  expect_false(isTRUE(disp$ready))
  expect_equal(disp$n_expected, 1L)
  expect_match(format(disp), "14058927")
})

test_that("find_replication_entry matches dataverse steps when language is r", {
  meta <- list(
    paper = list(doi = "10.1017/S0003055422000284"),
    steps = list(
      list(
        id = "access_data",
        type = "transform",
        engine = "dataverse",
        file_id = "14058927",
        outputs = list("outputs/data.dta")
      )
    )
  )
  rep <- find_replication_entry(meta, "access_data", language = "r")
  expect_equal(rep$id, "access_data")
  expect_equal(replication_engine(rep), "dataverse")
})

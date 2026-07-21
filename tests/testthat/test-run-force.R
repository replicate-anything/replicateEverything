test_that("run_replication defaults to live run when outputs/ already exist", {
  with_fixture_opts({
    study_dir <- file.path(
      getOption("replicateEverything.study_folders_root"),
      "rep-10.9999_example"
    )
    skip_if_not(dir.exists(study_dir), "fixture study repo missing")

    out_dir <- file.path(study_dir, "outputs")
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    out_file <- file.path(out_dir, "tab_1.html")
    writeLines("<html>precomputed-display-artifact</html>", out_file)
    withr::defer({
      if (file.exists(out_file)) {
        unlink(out_file)
      }
    })

    msgs <- character(0)
    withCallingHandlers(
      {
        withr::with_options(
          list(replicateEverything.quiet_run = TRUE),
          {
            invisible(capture.output({
              obj <- run_replication(fixture_doi(), "tab_1", format = FALSE)
            }))
          }
        )
      },
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )

    expect_true(any(grepl("Running step:\\s*tab_1", msgs)))
    expect_false(any(grepl("Using existing output for step:\\s*tab_1", msgs)))
    expect_true(is.data.frame(obj) || is.list(obj))
  })
})

test_that("force=FALSE reuses upstream outputs but still runs the target", {
  with_fixture_opts({
    fixtures_root <- getOption("replicateEverything.study_folders_root")
    skip_if_not(dir.exists(fixtures_root), "fixture study root missing")
    tmp <- file.path(fixtures_root, "rep-force-cache-tmp")
    unlink(tmp, recursive = TRUE, force = TRUE)
    dir.create(file.path(tmp, "code"), recursive = TRUE)
    dir.create(file.path(tmp, "outputs", "prep_a"), recursive = TRUE)
    withr::defer(unlink(tmp, recursive = TRUE, force = TRUE))

    writeLines("ok", file.path(tmp, "outputs", "prep_a", "data.csv"))
    writeLines("<html>old</html>", file.path(tmp, "outputs", "tab_1.html"))
    writeLines(
      c(
        "make_prep_a <- function(data = NULL) {",
        "  writeLines('prep-ran', file.path('outputs', 'prep_a', 'ran.txt'))",
        "  data.frame(x = 1)",
        "}",
        "make_tab_1 <- function(data = NULL) {",
        "  writeLines('tab-ran', file.path('outputs', 'tab_ran.txt'))",
        "  data.frame(ok = TRUE)",
        "}"
      ),
      file.path(tmp, "code", "steps.R")
    )
    yaml::write_yaml(
      list(
        paper = list(
          study_handle = "force-cache-tmp",
          title = "Force cache temp",
          year = 2026,
          authors = "Test",
          materials = "folder"
        ),
        languages = list("r"),
        steps = list(
          list(
            id = "prep_a",
            type = "transform",
            label = "Prep A",
            parents = list(),
            code = "code/steps.R",
            outputs = list("outputs/prep_a/")
          ),
          list(
            id = "tab_1",
            type = "table",
            label = "Table 1",
            parents = list("prep_a"),
            code = "code/steps.R",
            outputs = list("outputs/tab_1.html")
          )
        )
      ),
      file.path(tmp, "replication.yml")
    )

    msgs <- character(0)
    withCallingHandlers(
      {
        withr::with_options(
          list(replicateEverything.quiet_run = TRUE),
          {
            invisible(capture.output({
              run_replication(
                "force-cache-tmp",
                "tab_1",
                given = "nothing",
                force = FALSE,
                format = FALSE
              )
            }))
          }
        )
      },
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )

    expect_true(any(grepl("Using existing output for step:\\s*prep_a", msgs)))
    expect_true(any(grepl("Running step:\\s*tab_1", msgs)))
    expect_false(any(grepl("Using existing output for step:\\s*tab_1", msgs)))
    # Upstream skip means prep script side effects are absent
    expect_false(file.exists(file.path(tmp, "outputs", "prep_a", "ran.txt")))
  })
})

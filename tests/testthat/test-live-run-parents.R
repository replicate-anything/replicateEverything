test_that("assert_parents_ready checks parents even when force = TRUE", {
  with_fixture_opts({
    fixtures_root <- getOption("replicateEverything.study_folders_root")
    skip_if_not(dir.exists(fixtures_root), "fixture study root missing")
    tmp <- file.path(fixtures_root, "rep-live-parents-assert-tmp")
    unlink(tmp, recursive = TRUE, force = TRUE)
    dir.create(file.path(tmp, "code"), recursive = TRUE)
    dir.create(file.path(tmp, "outputs", "prep_a"), recursive = TRUE)
    withr::defer(unlink(tmp, recursive = TRUE, force = TRUE))

    writeLines(
      c(
        "make_prep_a <- function(data = NULL) { data.frame(x = 1) }",
        "make_tab_1 <- function(data = NULL) { data.frame(ok = TRUE) }"
      ),
      file.path(tmp, "code", "steps.R")
    )
    yaml::write_yaml(
      list(
        paper = list(
          study_handle = "live-parents-assert-tmp",
          title = "Live parents assert",
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

    expect_error(
      run_replication(
        "live-parents-assert-tmp",
        "tab_1",
        given = "parents",
        force = TRUE,
        format = FALSE
      ),
      "Parent step output\\(s\\) missing|Bake and commit"
    )
  })
})

test_that("Live Run path does not rebuild missing parents", {
  with_fixture_opts({
    fixtures_root <- getOption("replicateEverything.study_folders_root")
    skip_if_not(dir.exists(fixtures_root), "fixture study root missing")
    tmp <- file.path(fixtures_root, "rep-live-no-rebuild-tmp")
    unlink(tmp, recursive = TRUE, force = TRUE)
    dir.create(file.path(tmp, "code"), recursive = TRUE)
    dir.create(file.path(tmp, "outputs", "prep_a"), recursive = TRUE)
    withr::defer(unlink(tmp, recursive = TRUE, force = TRUE))

    writeLines(
      c(
        "make_prep_a <- function(data = NULL) {",
        "  writeLines('prep-ran', file.path('outputs', 'prep_a', 'ran.txt'))",
        "  writeLines('ok', file.path('outputs', 'prep_a', 'data.csv'))",
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
          study_handle = "live-no-rebuild-tmp",
          title = "Live no rebuild",
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
    out <- withCallingHandlers(
      {
        load_replication_for_display(
          "live-no-rebuild-tmp",
          "tab_1",
          prefer = "live",
          fallback_live = FALSE,
          install_deps = FALSE
        )
      },
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )

    expect_false(isTRUE(out$ok))
    expect_true(inherits(out$error, "error"))
    expect_match(conditionMessage(out$error), "Parent step output|Bake and commit")
    expect_false(any(grepl("Running upstream step:", msgs, fixed = TRUE)))
    expect_false(file.exists(file.path(tmp, "outputs", "prep_a", "ran.txt")))
    expect_false(file.exists(file.path(tmp, "outputs", "tab_ran.txt")))
  })
})

test_that("Live Run happy path runs leaf when parent sinks exist", {
  with_fixture_opts({
    fixtures_root <- getOption("replicateEverything.study_folders_root")
    skip_if_not(dir.exists(fixtures_root), "fixture study root missing")
    tmp <- file.path(fixtures_root, "rep-live-happy-tmp")
    unlink(tmp, recursive = TRUE, force = TRUE)
    dir.create(file.path(tmp, "code"), recursive = TRUE)
    dir.create(file.path(tmp, "outputs", "prep_a"), recursive = TRUE)
    withr::defer(unlink(tmp, recursive = TRUE, force = TRUE))

    writeLines("ok", file.path(tmp, "outputs", "prep_a", "data.csv"))
    writeLines(
      c(
        "make_prep_a <- function(data = NULL) {",
        "  writeLines('prep-ran', file.path('outputs', 'prep_a', 'ran.txt'))",
        "  data.frame(x = 1)",
        "}",
        "make_tab_1 <- function(data = NULL) {",
        "  writeLines('tab-ran', file.path('outputs', 'tab_ran.txt'))",
        "  data.frame(ok = TRUE)",
        "}",
        "format_tab_1 <- function(x) {",
        "  paste0('<table><tr><td>', x$ok[[1]], '</td></tr></table>')",
        "}"
      ),
      file.path(tmp, "code", "steps.R")
    )
    yaml::write_yaml(
      list(
        paper = list(
          study_handle = "live-happy-tmp",
          title = "Live happy",
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
            code = "code/steps.R",
            outputs = list("outputs/prep_a/")
          ),
          list(
            id = "tab_1",
            type = "table",
            label = "Table 1",
            parents = list("prep_a"),
            code = "code/steps.R",
            format = "code/steps.R",
            outputs = list("outputs/tab_1.html")
          )
        )
      ),
      file.path(tmp, "replication.yml")
    )

    msgs <- character(0)
    out <- withCallingHandlers(
      {
        load_replication_for_display(
          "live-happy-tmp",
          "tab_1",
          prefer = "live",
          fallback_live = FALSE,
          install_deps = FALSE
        )
      },
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )

    expect_true(isTRUE(out$ok))
    expect_equal(out$source, "live")
    expect_true(any(grepl("Running step:\\s*tab_1", msgs)))
    expect_false(any(grepl("Running upstream step:", msgs, fixed = TRUE)))
    expect_false(any(grepl("Running step:\\s*prep_a", msgs)))
    # Parent must not have been re-executed for Live Run leaf-only path.
    expect_false(file.exists(file.path(tmp, "outputs", "prep_a", "ran.txt")))
  })
})

test_that("fixture Live Run still works without parents", {
  with_fixture_opts({
    study_dir <- file.path(
      getOption("replicateEverything.study_folders_root"),
      "rep-10.9999-example"
    )
    skip_if_not(dir.exists(study_dir), "fixture study repo missing")

    out <- load_replication_for_display(
      fixture_doi(),
      "tab_1",
      prefer = "live",
      fallback_live = FALSE,
      install_deps = FALSE
    )
    expect_true(isTRUE(out$ok))
    expect_equal(out$source, "live")
  })
})

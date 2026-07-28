test_that("step_path_languages prefers explicit languages:", {
  step <- list(
    id = "a",
    engine = "stata",
    languages = list("stata", "r")
  )
  expect_equal(step_path_languages(step), c("stata", "r"))
})

test_that("step_path_languages falls back to engine + requires_engine", {
  step <- list(
    id = "a",
    engine = "stata",
    requires_engine = "mathematica"
  )
  expect_equal(step_path_languages(step), c("stata", "mathematica"))
})

test_that("format_path_languages_box_label builds Shiny labels", {
  expect_equal(
    format_path_languages_box_label(c("stata", "r")),
    "[Stata / R]"
  )
  expect_equal(
    format_path_languages_box_label(c("stata", "mathematica")),
    "[Stata / Mathematica]"
  )
})

test_that("group_uses_path_boxes detects multi-language path groups", {
  sibs <- list(
    list(
      id = "compute_mvpf_main",
      group = "compute_mvpf_main",
      engine = "stata",
      languages = list("stata", "r")
    ),
    list(
      id = "compute_mvpf_main_mathematica",
      group = "compute_mvpf_main",
      engine = "stata",
      languages = list("stata", "mathematica"),
      incomplete = TRUE,
      requires_engine = "mathematica"
    )
  )
  expect_true(group_uses_path_boxes(sibs))
  expect_false(group_uses_path_boxes(sibs[1]))
})

test_that("group_uses_path_boxes is false for classic bilingual R/Stata", {
  sibs <- list(
    list(id = "tab_1", group = "tab_1", engine = "r", code = "a.R"),
    list(id = "tab_1_stata", group = "tab_1", engine = "stata", code = "a.do")
  )
  expect_false(group_uses_path_boxes(sibs))
})

test_that("path selector prefers runnable R path", {
  sibs <- list(
    list(
      id = "compute_mvpf_main",
      group = "compute_mvpf_main",
      engine = "stata",
      languages = list("stata", "r")
    ),
    list(
      id = "compute_mvpf_main_mathematica",
      group = "compute_mvpf_main",
      engine = "stata",
      languages = list("stata", "mathematica"),
      incomplete = TRUE,
      requires_engine = "mathematica"
    )
  )
  expect_equal(default_path_selector_language(sibs), "r")
  expect_equal(path_selector_language(sibs[[1]], sibs), "r")
  expect_equal(path_selector_language(sibs[[2]], sibs), "mathematica")

  r_path <- pick_path_entry(sibs, "r")
  m_path <- pick_path_entry(sibs, "mathematica")
  expect_equal(r_path$id, "compute_mvpf_main")
  expect_equal(m_path$id, "compute_mvpf_main_mathematica")
})

test_that("find_replication_entry resolves path languages for same engine", {
  meta <- list(
    paper = list(doi = "10.5555/test"),
    steps = list(
      list(
        id = "compute_mvpf_main",
        group = "compute_mvpf_main",
        type = "transform",
        engine = "stata",
        languages = list("stata", "r"),
        code = "code/a.do",
        outputs = list("outputs/a.dta")
      ),
      list(
        id = "compute_mvpf_main_mathematica",
        group = "compute_mvpf_main",
        type = "transform",
        engine = "stata",
        languages = list("stata", "mathematica"),
        incomplete = TRUE,
        requires_engine = "mathematica",
        code = "code/b.do",
        outputs = list("outputs/b.dta")
      )
    )
  )
  expect_equal(
    find_replication_entry(meta, "compute_mvpf_main", language = "r")$id,
    "compute_mvpf_main"
  )
  expect_equal(
    find_replication_entry(meta, "compute_mvpf_main", language = "mathematica")$id,
    "compute_mvpf_main_mathematica"
  )
  expect_equal(
    find_replication_entry(meta, "compute_mvpf_main")$id,
    "compute_mvpf_main"
  )
})

test_that("shiny_step_show_display still omits Display for mathematica path gaps", {
  expect_false(shiny_step_show_display(
    output_exists = FALSE,
    gap_kind = "hammer",
    incomplete = TRUE
  ))
  expect_true(shiny_step_show_display(
    output_exists = TRUE,
    gap_kind = "hammer",
    incomplete = TRUE
  ))
})

test_that("replication_sidebar_data_order follows yaml order and collapses groups", {
  reps <- list(
    list(id = "clean_data", type = "transform", engine = "stata"),
    list(id = "macros", type = "transform", engine = "stata", parents = list("clean_data")),
    list(
      id = "cost_curve_data_r",
      type = "transform",
      engine = "r"
    ),
    list(
      id = "compute_mvpf_main",
      group = "compute_mvpf_main",
      type = "transform",
      engine = "stata",
      languages = list("stata", "r")
    ),
    list(
      id = "compute_mvpf_main_mathematica",
      group = "compute_mvpf_main",
      type = "transform",
      engine = "stata",
      languages = list("stata", "mathematica"),
      incomplete = TRUE
    ),
    list(id = "tab_1", type = "table", engine = "stata", parents = list("compute_mvpf_main"))
  )
  expect_equal(
    replication_sidebar_data_order(reps),
    c("clean_data", "macros", "cost_curve_data_r", "compute_mvpf_main")
  )
  # Multi-path group appears once (not before prep).
  expect_equal(
    which(replication_sidebar_data_order(reps) == "compute_mvpf_main"),
    4L
  )
})

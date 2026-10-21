test_that("study_sidebar_section_labels reads root sidebar:", {
  meta <- list(sidebar = list("Figures", "Key numbers", "SI Figures", "SI Tables"))
  expect_identical(
    study_sidebar_section_labels(meta),
    c("Figures", "Key numbers", "SI Figures", "SI Tables")
  )
  expect_identical(study_sidebar_section_labels(list()), character(0))
})

test_that("is_sidebar_steps_label matches Steps and legacy Data steps", {
  expect_true(is_sidebar_steps_label("Steps"))
  expect_true(is_sidebar_steps_label("steps"))
  expect_true(is_sidebar_steps_label("STEPS"))
  expect_true(is_sidebar_steps_label("Data steps"))
  expect_true(is_sidebar_steps_label("data steps"))
  expect_false(is_sidebar_steps_label("Figures"))
  expect_false(is_sidebar_steps_label(""))
})

test_that("study_sidebar_exhibit_labels strips Steps token", {
  meta <- list(sidebar = list("Figures", "Steps", "SI Tables"))
  expect_identical(
    study_sidebar_exhibit_labels(meta),
    c("Figures", "SI Tables")
  )
  expect_identical(
    study_sidebar_exhibit_labels(c("Key numbers", "data steps")),
    "Key numbers"
  )
  expect_identical(study_sidebar_exhibit_labels(list()), character(0))
})

test_that("sidebar_unified_plan: legacy no sidebar keeps Data steps on top", {
  secs <- list(
    list(title = "Figures", rows = data.frame(id = "fig_1", stringsAsFactors = FALSE)),
    list(title = "Tables", rows = data.frame(id = "tab_1", stringsAsFactors = FALSE))
  )
  plan <- sidebar_unified_plan(character(0), secs, has_data = TRUE)
  expect_identical(
    vapply(plan, function(x) x$kind, character(1)),
    c("data", "exhibit", "exhibit")
  )
  expect_identical(plan[[1]]$title, "Data steps")
  expect_identical(plan[[2]]$title, "Figures")
  expect_identical(plan[[3]]$title, "Tables")
})

test_that("sidebar_unified_plan: Steps last places data at end with Steps heading", {
  secs <- list(
    list(title = "Figures", rows = data.frame(id = "fig_1", stringsAsFactors = FALSE)),
    list(title = "Key numbers", rows = data.frame(id = "key", stringsAsFactors = FALSE))
  )
  plan <- sidebar_unified_plan(
    c("Figures", "Key numbers", "Steps"),
    secs,
    has_data = TRUE
  )
  expect_identical(
    vapply(plan, function(x) paste(x$kind, x$title, sep = ":"), character(1)),
    c("exhibit:Figures", "exhibit:Key numbers", "data:Steps")
  )
})

test_that("sidebar_unified_plan: Steps omitted from list prepends Steps", {
  secs <- list(
    list(title = "Figures", rows = data.frame(id = "fig_1", stringsAsFactors = FALSE))
  )
  plan <- sidebar_unified_plan(c("Figures", "SI Tables"), secs, has_data = TRUE)
  expect_identical(plan[[1]]$kind, "data")
  expect_identical(plan[[1]]$title, "Steps")
  expect_identical(plan[[2]]$title, "Figures")
})

test_that("sidebar_unified_plan: no empty Steps when has_data FALSE", {
  secs <- list(
    list(title = "Figures", rows = data.frame(id = "fig_1", stringsAsFactors = FALSE))
  )
  plan <- sidebar_unified_plan(c("Figures", "Steps"), secs, has_data = FALSE)
  expect_length(plan, 1L)
  expect_identical(plan[[1]]$kind, "exhibit")
})

test_that("sidebar_unified_plan: legacy Data steps token still positions block", {
  secs <- list(
    list(title = "Figures", rows = data.frame(id = "fig_1", stringsAsFactors = FALSE))
  )
  plan <- sidebar_unified_plan(c("Figures", "Data steps"), secs, has_data = TRUE)
  expect_identical(plan[[2]]$kind, "data")
  expect_identical(plan[[2]]$title, "Steps")
})

test_that("step_sidebar_family uses family or type default", {
  expect_identical(
    step_sidebar_family(list(type = "figure", family = "SI Figures")),
    "SI Figures"
  )
  expect_identical(step_sidebar_family(list(type = "figure")), "Figures")
  expect_identical(step_sidebar_family(list(type = "table")), "Tables")
})

test_that("legacy type-run sections group consecutive types", {
  exhibit <- data.frame(
    id = c("fig_1", "fig_2", "tab_1"),
    type = c("figure", "figure", "table"),
    family = c("", "", ""),
    stringsAsFactors = FALSE
  )
  secs <- exhibit_type_run_sections(exhibit)
  expect_length(secs, 2L)
  expect_identical(secs[[1]]$title, "Figures")
  expect_identical(secs[[1]]$rows$id, c("fig_1", "fig_2"))
  expect_identical(secs[[2]]$title, "Tables")
})

test_that("exhibit_sidebar_sections orders by sidebar then leftovers", {
  exhibit <- data.frame(
    id = c("fig_1", "key_numbers", "fig_s2", "tab_s1"),
    type = c("figure", "table", "figure", "table"),
    family = c("Figures", "Key numbers", "SI Figures", "SI Tables"),
    stringsAsFactors = FALSE
  )
  secs <- exhibit_sidebar_sections(
    exhibit,
    c("Figures", "Key numbers", "SI Figures", "SI Tables")
  )
  expect_identical(
    vapply(secs, function(s) s$title, character(1)),
    c("Figures", "Key numbers", "SI Figures", "SI Tables")
  )
  expect_identical(secs[[1]]$rows$id, "fig_1")
  expect_identical(secs[[2]]$rows$id, "key_numbers")
  expect_identical(secs[[3]]$rows$id, "fig_s2")
  expect_identical(secs[[4]]$rows$id, "tab_s1")
})

test_that("exhibit_sidebar_sections ignores Steps token in sidebar labels", {
  exhibit <- data.frame(
    id = "fig_1",
    type = "figure",
    family = "Figures",
    stringsAsFactors = FALSE
  )
  secs <- exhibit_sidebar_sections(exhibit, c("Figures", "Steps", "SI Tables"))
  expect_length(secs, 1L)
  expect_identical(secs[[1]]$title, "Figures")
})

test_that("study_uses_sidebar_sections detects sidebar or family", {
  expect_false(study_uses_sidebar_sections(list(), list()))
  expect_true(study_uses_sidebar_sections(list(sidebar = list("Figures")), list()))
  expect_true(study_uses_sidebar_sections(
    list(),
    data.frame(family = "SI Figures", stringsAsFactors = FALSE)
  ))
  # Steps-only sidebar does not force exhibit section mode
  expect_false(study_uses_sidebar_sections(list(sidebar = list("Steps")), list()))
})

test_that("section mode does not invent empty sidebar sections", {
  exhibit <- data.frame(
    id = "fig_1",
    type = "figure",
    family = "Figures",
    stringsAsFactors = FALSE
  )
  secs <- exhibit_sidebar_sections(
    exhibit,
    c("Figures", "Key numbers", "SI Figures")
  )
  expect_length(secs, 1L)
  expect_identical(secs[[1]]$title, "Figures")
})

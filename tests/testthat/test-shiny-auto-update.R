test_that("package_sha_update_status classifies SHAs", {
  expect_equal(package_sha_update_status("abc1234", "abc1234"), "current")
  expect_equal(
    package_sha_update_status(
      "abc1234deadbeef",
      "abc1234ffffffffffff"
    ),
    "current"
  )
  expect_equal(package_sha_update_status("aaa1111", "bbb2222"), "outdated")
  expect_equal(package_sha_update_status(NA_character_, "bbb2222"), "outdated")
  expect_equal(package_sha_update_status("aaa1111", NA_character_), "unknown")
  expect_equal(package_sha_update_status(NA_character_, NA_character_), "unknown")
  expect_equal(package_sha_update_status("", "bbb2222"), "outdated")
})

test_that("shiny_auto_update_enabled reads both option names", {
  withr::with_options(
    list(
      replicate_shiny.auto_update_replicate_everything = NULL,
      replicateEverything.shiny_auto_update = NULL
    ),
    expect_true(shiny_auto_update_enabled())
  )
  withr::with_options(
    list(replicate_shiny.auto_update_replicate_everything = FALSE),
    expect_false(shiny_auto_update_enabled())
  )
  withr::with_options(
    list(
      replicate_shiny.auto_update_replicate_everything = NULL,
      replicateEverything.shiny_auto_update = FALSE
    ),
    expect_false(shiny_auto_update_enabled())
  )
  withr::with_options(
    list(
      replicate_shiny.auto_update_replicate_everything = TRUE,
      replicateEverything.shiny_auto_update = FALSE
    ),
    expect_true(shiny_auto_update_enabled())
  )
})

test_that("ensure_replicate_everything_current skips when disabled", {
  withr::with_options(
    list(
      replicate_shiny.auto_update_replicate_everything = FALSE,
      replicateEverything.shiny_auto_update = NULL,
      replicate_shiny.use_local_replicate_everything = FALSE,
      replicate_shiny.auto_update_status = NULL
    ),
    {
      status <- ensure_replicate_everything_current(install = FALSE)
      expect_equal(status$state, "disabled")
      expect_false(status$enabled)
      expect_identical(
        getOption("replicate_shiny.auto_update_status")$state,
        "disabled"
      )
    }
  )
})

test_that("ensure_replicate_everything_current skips local load_all", {
  withr::with_options(
    list(
      replicate_shiny.auto_update_replicate_everything = TRUE,
      replicate_shiny.use_local_replicate_everything = TRUE,
      replicate_shiny.auto_update_status = NULL
    ),
    {
      status <- ensure_replicate_everything_current(install = FALSE)
      expect_equal(status$state, "local_dev")
      expect_false(status$enabled)
    }
  )
})

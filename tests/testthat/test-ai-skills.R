test_that("bundled AI skills are discoverable", {
  skills <- ai_skills()
  expect_true("dataverse_to_replicateEverything" %in% skills)
  expect_true("folder_replication" %in% skills)
  expect_false("README" %in% skills)

  path <- ai_skill_path("dataverse_to_replicateEverything")
  expect_true(file.exists(path))
  expect_true(grepl("Harvard Dataverse", ai_skill("dataverse_to_replicateEverything")))
})

test_that("ai_skill_path reports available skills on miss", {
  expect_error(
    ai_skill_path("not_a_real_skill"),
  "AI skill not found: not_a_real_skill"
  )
})

test_that("python_executable_candidates skips Windows Store stubs", {
  skip_if_not(.Platform$OS.type == "windows", "Windows only")
  cands <- replicateEverything:::python_executable_candidates()
  expect_false(any(grepl("WindowsApps", cands, ignore.case = TRUE)))
})

test_that("find_python_executable prefers py launcher installs on Windows", {
  skip_if_not(.Platform$OS.type == "windows", "Windows only")
  py <- replicateEverything:::find_python_executable()
  expect_false(grepl("WindowsApps", py, ignore.case = TRUE))
})

test_that("first_author_surname drops middle initials", {
  expect_equal(first_author_surname("Robert A. Blair"), "Blair")
  expect_equal(first_author_surname("Robert A Blair"), "Blair")
  expect_equal(first_author_surname("Manuel Moscoso"), "Moscoso")
})

test_that("first_author_surname keeps compound surnames", {
  expect_equal(first_author_surname("Andrés Vargas Castillo"), "Vargas Castillo")
})

test_that("format_author_label uses corrected surnames", {
  authors <- "Robert A. Blair, Manuel Moscoso, Andrés Vargas Castillo, Michael Weintraub"
  expect_equal(format_author_label(authors), "Blair et al")
})

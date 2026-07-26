test_that("first_author_surname drops middle initials", {
  expect_equal(first_author_surname("Robert A. Blair"), "Blair")
  expect_equal(first_author_surname("Robert A Blair"), "Blair")
  expect_equal(first_author_surname("Manuel Moscoso"), "Moscoso")
})

test_that("first_author_surname keeps compound surnames", {
  expect_equal(first_author_surname("Andrés Vargas Castillo"), "Vargas Castillo")
})

test_that("first_author_surname reads Last, First form", {
  expect_equal(first_author_surname("Velez, Yamil Ricardo"), "Velez")
})

test_that("first_author_surname uses Madsen from Last, First (not Rask Madsen)", {
  expect_equal(first_author_surname("Madsen, Mikael Rask"), "Madsen")
  expect_equal(
    format_author_label("Madsen, Mikael Rask, Mayoral, Juan, Strezhnev, Anton, Voeten, Erik"),
    "Madsen et al"
  )
  # First Middle Last without comma triggers compound-surname heuristic
  expect_equal(first_author_surname("Mikael Rask Madsen"), "Rask Madsen")
})

test_that("parse_author_names preserves Last, First pairs", {
  authors <- parse_author_names("Velez, Yamil Ricardo, Liu, Patrick, Clifford, Scott")
  expect_equal(
    authors,
    c("Velez, Yamil Ricardo", "Liu, Patrick", "Clifford, Scott")
  )
})

test_that("format_author_label uses corrected surnames", {
  authors <- "Robert A. Blair, Manuel Moscoso, Andrés Vargas Castillo, Michael Weintraub"
  expect_equal(format_author_label(authors), "Blair et al")
})

test_that("format_author_label uses Velez surname from Last, First yaml", {
  authors <- "Velez, Yamil Ricardo, Liu, Patrick, Clifford, Scott"
  expect_equal(format_author_label(authors), "Velez et al")
})

test_that("format_authors_summary uses Last, First display", {
  authors <- "Velez, Yamil Ricardo, Liu, Patrick, Clifford, Scott"
  expect_equal(
    format_authors_summary(authors),
    "Velez, Yamil Ricardo, Liu, Patrick, and Clifford, Scott"
  )
})

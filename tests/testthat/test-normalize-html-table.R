test_that("normalize_html_table converts LaTeX checkmarks", {
  html <- "<td>$\\checkmark$</td><td>\\checkmark</td>"
  out <- normalize_html_table(html)
  expect_equal(out, "<td>\u2713</td><td>\u2713</td>")
})

test_that("normalize_html_table converts Portraits-style table cells", {
  html <- "<tr><td>Birth year FE</td><td>$\\checkmark$</td></tr>"
  out <- normalize_html_table(html)
  expect_match(out, "Birth year FE")
  expect_match(out, "\u2713")
  expect_false(grepl("\\\\checkmark", out))
})

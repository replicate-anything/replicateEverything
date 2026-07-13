test_that("sanitize_esttab_html removes LaTeX fragments", {
  raw <- paste0(
    "<tr><td></td>",
    "<td>\\multicolumn{2}{c}{Any unresolved disputes}</td>",
    "<td>\\multicolumn{2}{c}{Any violent disputes}</td>",
    "</tr>\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}"
  )
  out <- sanitize_esttab_html(raw)
  expect_false(grepl("\\\\multicolumn", out))
  expect_false(grepl("\\\\cmidrule", out))
  expect_true(grepl("Any unresolved disputes", out, fixed = TRUE))
  expect_true(grepl("colspan=\"2\"", out, fixed = TRUE))
})

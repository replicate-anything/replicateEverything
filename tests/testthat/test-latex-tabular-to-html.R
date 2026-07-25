test_that("latex_tabular_to_html converts texdoc tabular to HTML table", {
  tex <- paste(
    "\\begin{table}[h]",
    "\\caption{Example click table}",
    "\\begin{tabular}{lcccc} \\hline \\hline",
    "\\\\",
    "&& \\multicolumn{2}{c}{Municipality} & \\multicolumn{2}{c}{Email}\\\\",
    "&& (1) & (2) & (3) & (4) \\\\",
    "\\hline",
    "Aligned ideology && 0.01 & 0.02 & 0.00 & -0.00\\\\",
    "&& (0.01) & (0.01) & (0.01) & (0.01) \\\\",
    "\\textit{Panel note} \\\\",
    "N && 100 & 100 & 200 & 200 \\\\",
    "\\\\ \\hline \\hline",
    "\\end{tabular}",
    "\\end{table}",
    sep = "\n"
  )
  html <- latex_tabular_to_html(tex, title = "Table 3")
  expect_true(grepl("<table", html, fixed = TRUE))
  expect_true(grepl("colspan=\"2\"", html, fixed = TRUE))
  expect_true(grepl("Municipality", html, fixed = TRUE))
  expect_true(grepl("<em>Panel note</em>", html, fixed = TRUE))
  expect_true(grepl("<h3>Table 3</h3>", html, fixed = TRUE))
  expect_false(grepl("\\\\begin\\{tabular\\}", html))
  expect_false(grepl("<pre", html, fixed = TRUE))
})

test_that("latex_tabular_to_html reads .tex file paths", {
  tmp <- tempfile(fileext = ".tex")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(
    c(
      "\\begin{tabular}{lc}",
      "A & B \\\\",
      "1 & 2 \\\\",
      "\\end{tabular}"
    ),
    tmp
  )
  html <- latex_tabular_to_html(tmp)
  expect_true(grepl("<td>A</td>", html, fixed = TRUE))
  expect_true(grepl("<td>2</td>", html, fixed = TRUE))
})

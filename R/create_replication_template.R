#' Create a replication template
#'
#' @param doi Character. DOI of the paper.
#' @export
create_replication_template <- function(doi) {
  meta <- get_doi_metadata(doi)
  doi_clean <- normalize_doi(doi)
  doi_path <- resolve_paper_path(doi_clean)
  authors <- paste(meta$authors, collapse = ", ")
  github_url <- paste0(
    "https://github.com/replicate-anything/registry/tree/main/papers/", doi_path
  )

  dir.create(doi_path, showWarnings = FALSE)
  dir.create(file.path(doi_path, "code"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(doi_path, "data"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(doi_path, "artifacts"), recursive = TRUE, showWarnings = FALSE)

  yaml <- paste0(
    "paper:
  doi: https://doi.org/", doi_clean, "
  title: ", meta$title, "
  journal: ", meta$journal, "
  year: ", meta$year, "
  authors: ", authors, "
  dependencies:
    - ggplot2

replications:

  - id: fig_1
    type: figure
    label: Figure 1
    description: Example figure
    data: data/example.csv
    code: code/fig_1.R
    artifact: artifacts/fig_1.png
    dependencies:
      - ggplot2

  - id: tab_1
    type: table
    label: Table 1
    description: Example table
    data: data/example.csv
    code: code/tab_1.R
    format: format_tab_1
    artifact: artifacts/tab_1.rds
    dependencies:
      - ggplot2
"
  )

  writeLines(yaml, file.path(doi_path, "replication.yml"))

  example_data <- data.frame(x = 1:5, y = c(2, 4, 3, 5, 6))
  write.csv(example_data, file.path(doi_path, "data", "example.csv"), row.names = FALSE)

  writeLines(
    c(
      "# Figure 1 - ", meta$title,
      "# Paper folder: ", github_url,
      "# Run from the paper's code/ folder: Rscript fig_1.R",
      "",
      "library(ggplot2)",
      "",
      "make_fig_1 <- function(data) {",
      "  ggplot2::ggplot(data, ggplot2::aes(x, y)) +",
      "    ggplot2::geom_line() +",
      "    ggplot2::theme_minimal()",
      "}",
      "",
      "make_fig_1(utils::read.csv(\"../data/example.csv\", stringsAsFactors = FALSE))"
    ),
    file.path(doi_path, "code", "fig_1.R")
  )

  writeLines(
    c(
      "# Table 1 - ", meta$title,
      "# Paper folder: ", github_url,
      "# Run from the paper's code/ folder: Rscript tab_1.R",
      "# Requires the data/ folder alongside code/ (see replication.yml).",
      "",
      "library(ggplot2)",
      "",
      "make_tab_1 <- function(data) {",
      "  summary(lm(y ~ x, data = data))",
      "}",
      "",
      "format_tab_1 <- function(object) {",
      "  paste(capture.output(print(object)), collapse = \"\\n\")",
      "}",
      "",
      "make_tab_1(utils::read.csv(\"../data/example.csv\", stringsAsFactors = FALSE)) |> format_tab_1()"
    ),
    file.path(doi_path, "code", "tab_1.R")
  )

  message("Replication template created at: ", doi_path)
}

#' Create a replication template
#'
#' @param doi Character. DOI of the paper.
#'
#' @examples
#' \dontrun{
#' create_replication_template("10.1177/00491241211036161")
#' }
#'
#' @export
create_replication_template <- function(doi) {
  meta <- get_doi_metadata(doi)
  doi_clean <- normalize_doi(doi)
  registry_folder <- resolve_paper_path(doi_clean)
  study_folder <- paste0("rep-", gsub("_", "-", registry_folder))
  authors <- paste(meta$authors, collapse = ", ")
  github_url <- paste0(
    "https://github.com/replicate-anything/", study_folder
  )

  dir.create(study_folder, showWarnings = FALSE)
  dir.create(file.path(study_folder, "code"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(study_folder, "data"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(study_folder, "artifacts"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(study_folder, "tests", "testthat"), recursive = TRUE, showWarnings = FALSE)

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

  writeLines(yaml, file.path(study_folder, "replication.yml"))

  example_data <- data.frame(x = 1:5, y = c(2, 4, 3, 5, 6))
  write.csv(example_data, file.path(study_folder, "data", "example.csv"), row.names = FALSE)

  writeLines(
    c(
      "# Figure 1 - ", meta$title,
      "# Study repo: ", github_url,
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
    file.path(study_folder, "code", "fig_1.R")
  )

  writeLines(
    c(
      "# Table 1 - ", meta$title,
      "# Study repo: ", github_url,
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
    file.path(study_folder, "code", "tab_1.R")
  )

  message("Folder-backed study template created at: ", study_folder)
  message("Register with prepare_folder_paper() then sync to registry/papers/", registry_folder, ".yml")
}

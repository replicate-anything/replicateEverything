#' Create a replication template
#'
#' Creates a folder structure and template files for replicating a paper.
#'
#' @param doi Character DOI of the paper.
#'
#' @importFrom utils write.csv
#' @export
create_replication_template <- function(doi){

  meta <- get_doi_metadata(doi)

  doi_clean <- normalize_doi(doi)

  doi_path <- gsub("/", "_", doi_clean)

  authors <- paste(meta$authors, collapse = ", ")

  # Create directories
  dir.create(doi_path, showWarnings = FALSE)
  dir.create(file.path(doi_path,"code"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(doi_path,"processed"), recursive = TRUE, showWarnings = FALSE)

  yaml <- paste0(
    "paper:
  doi: https://doi.org/", doi_clean,"
  title: ",meta$title,"
  journal: ",meta$journal,"
  year: ",meta$year,"
  authors: ",authors,"

replications:

  - id: fig_1
    type: figure
    description: Example figure
    data: processed/example.csv
    code: code/fig_1.R

  - id: tab_1
    type: table
    description: Example table
    data: processed/example.csv
    code: code/tab_1.R
"
  )

  writeLines(
    yaml,
    file.path(doi_path,"replication.yml")
  )

  example_data <- data.frame(
    x = 1:5,
    y = c(2,4,3,5,6)
  )

  write.csv(
    example_data,
    file.path(doi_path,"processed","example.csv"),
    row.names = FALSE
  )

  example_fig_code <- c(
    "generate_figure <- function(data){

  library(ggplot2)

  ggplot(data, aes(x,y)) +
    geom_line() +
    theme_minimal()

}"
  )

  writeLines(
    example_fig_code,
    file.path(doi_path,"code","fig_1.R")
  )

  example_table_code <- c(
    "generate_table <- function(data){

  data

}"
  )

  writeLines(
    example_table_code,
    file.path(doi_path,"code","tab_1.R")
  )

  message("Replication template created at: ", doi_path)

}

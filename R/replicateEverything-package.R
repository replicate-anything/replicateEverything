#' replicateEverything: Reproduce Empirical Research Results
#'
#' The `replicateEverything` package provides tools for discovering and
#' executing computational replications of empirical research papers.
#' It connects to a public replication registry containing metadata,
#' replication scripts, and processed datasets required to reproduce
#' figures and tables from published studies.
#'
#' @section Workflow:
#'
#' A typical workflow using the package is:
#'
#' 1. Retrieve metadata for a paper using \code{get_doi_metadata()}.
#' 2. Search the replication registry using \code{search_papers()}.
#' 3. Create a template for contributing a replication using
#'    \code{create_replication_template()}.
#' 4. Inspect available replications using \code{list_replications()}.
#' 5. Run a single replication using \code{run_replication()}.
#' 6. Reproduce all results from a paper using \code{replicate_paper()}.
#' 7. Launch the bundled Shiny demo with \code{run_shiny_app()}, or deploy it
#'    with \code{save_local_shiny()}.
#'
#' @section Examples:
#'
#' Retrieve metadata for a paper:
#'
#' get_doi_metadata("10.1177/00491241211036161")
#'
#' Search the registry:
#'
#' search_papers("causal")
#'
#' Create a replication template:
#'
#' create_replication_template("10.1177/00491241211036161")
#'
#' List replications:
#'
#' list_replications("10.1177/00491241211036161")
#'
#' Run a single replication:
#'
#' run_replication("10.1177/00491241211036161","fig_1")
#'
#' Replicate an entire paper:
#'
#' replicate_paper("10.1177/00491241211036161")
#'
#' Launch the Shiny demo:
#'
#' run_shiny_app()
#'
#' @section Shiny demo:
#'
#' A live instance runs at \url{https://shiny2.wzb.eu/ipi/replicate/}. The
#' package ships a demo app in \code{inst/shiny/}. Use
#' \code{\link[=run_shiny_app]{run_shiny_app()}} to launch it from an installed
#' build, or \code{\link[=save_local_shiny]{save_local_shiny()}} to copy
#' \code{app.R} and \code{www/} into a Shiny Server directory.
#'
#' @section Registry:
#'
#' Replication metadata and materials are stored in the public registry:
#' \url{https://github.com/replicate-anything/registry}.
#'
#' @keywords package
"_PACKAGE"

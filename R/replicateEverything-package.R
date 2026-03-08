#' replicateEverything: Replication Infrastructure for Empirical Research
#'
#' The \code{replicateEverything} package provides tools for discovering
#' and running computational replications of empirical research papers.
#' It connects to a replication registry that stores metadata,
#' replication code, and processed datasets for published studies.
#'
#' Users can search for replicated papers, list available replications
#' (such as figures or tables), and reproduce results directly from R.
#'
#' @section Core functions:
#'
#' \describe{
#'   \item{\code{get_doi_metadata()}}{Obtain the title, author's name, year, journal info from a DOI}
#'   \item{\code{search_papers()}}{Search the registry for replicated papers}
#'   \item{\code{create_replication_template()}}{Create a template folder on your local machine}
#'   \item{\code{list_replications()}}{List figures and tables available for a paper}
#'   \item{\code{run_replication()}}{Run a specific replication (figure or table)}
#'   \item{\code{replicate_paper()}}{Run all replications for a paper}
#' }
#'
#' @section Registry:
#'
#' Replications are stored in a public registry repository that contains
#' metadata files (\code{replication.yml}), replication scripts, and
#' processed datasets required to reproduce results.
#'
#' @section Example:
#'
#' \dontrun{
#' replicate_paper("10.1177/00491241211036161")
#' }
#'
#' @docType package
#' @name replicateEverything
NULL

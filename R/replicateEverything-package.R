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
#' 1. Browse the registry with \code{load_index()} or \code{search_papers()}.
#' 2. Inspect available replications using \code{list_replications()}.
#' 3. Run a single table or figure with \code{run_replication(doi, "fig_1")}.
#' 4. Reproduce all results with \code{run_replication(doi, "everything")}.
#' 5. View replication code with \code{get_code()}.
#' 6. Launch the bundled Shiny demo with \code{run_shiny_app()}, or deploy it
#'    with \code{save_local_shiny()}.
#' 7. Contribute a study with \code{build_study_outputs()},
#'    \code{check_replication()}, \code{prepare_study_for_registry()}, and
#'    \code{sync_study_to_registry()} (maintainer).
#' 8. Audit the full registry with \code{audit_everything()}.
#'
#' See \code{vignette("meet-the-functions")} for a tour of every main function.
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

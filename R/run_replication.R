#' Run a single replication
#'
#' Executes a specific replication (figure or table) for a paper.
#'
#' By default returns the raw analysis object (e.g. a \code{glm} or \code{ggplot}).
#' Set \code{format = TRUE} or \code{format = "if_available"} to apply the
#' registered \code{format_*} step when \code{replication.yml} defines one
#' (same step used for display artifacts and Shiny).
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (e.g., "fig_1").
#' @param install_deps Logical. Install missing CRAN dependencies when
#'   \code{TRUE}. Defaults to \code{FALSE}.
#' @param format Logical or \code{"if_available"}. When \code{TRUE} or
#'   \code{"if_available"}, apply formatting when the replication entry defines
#'   a \code{format} step. Defaults to \code{FALSE}.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return The replication object (analysis output or formatted display).
#'
#' @examples
#' \dontrun{
#' run_replication("10.1177/00491241211036161", "fig_1")
#' run_replication("10.1017/S0003055403000534", "tab_1", format = TRUE)
#' }
#'
#' @export
run_replication <- function(
  doi,
  what,
  install_deps = FALSE,
  format = FALSE,
  repo = NULL,
  folder = NULL
) {
  result <- render_replication(
    doi,
    what,
    install_deps = install_deps,
    repo = repo,
    folder = folder
  )
  object <- replication_object(result)

  apply_format <- isTRUE(format) || identical(format, "if_available")
  if (apply_format && isTRUE(result$has_format)) {
    object <- format_for_display(
      object,
      doi,
      what,
      install_deps = install_deps,
      repo = repo,
      folder = folder
    )
  }

  print(object)
  invisible(object)
}

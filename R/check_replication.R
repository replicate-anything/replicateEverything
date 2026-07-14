#' Validate a folder- or package-backed replication study
#'
#' Runs a transparent checklist: study layout, `replication.yml`, code and data
#' paths, resolvable code file links (`source()` / Stata `do`), baked display
#' outputs, optional `tests/testthat/`, substantive
#' (published-value) checks under `tests/substantive/`, and (optionally) live
#' execution of every table and figure.
#'
#' @param location Local study path, GitHub address, or installed package path.
#'   Defaults to the current working directory when it contains
#'   `replication.yml` or `DESCRIPTION`.
#' @param full_replication If `TRUE`, also run every table and figure via
#'   [run_replication()] and require success.
#' @param registry_root Optional path to the registry checkout (folder studies
#'   in a monorepo). Defaults to
#'   `getOption("replicateEverything.registry_root")`.
#' @return A list with `ok` (logical), `checks` (data frame), and `study_path`
#'   or `package_path`.
#'
#' @examples
#' \dontrun{
#' check_replication(".")
#' check_replication(".", full_replication = TRUE)
#' check_replication("../rep-10.1371_journal.pone.0278337")
#' }
#'
#' @export
check_replication <- function(
  location = ".",
  full_replication = FALSE,
  registry_root = NULL
) {
  root <- tryCatch(
    resolve_study_root(location),
    error = function(e) NULL
  )
  if (!is.null(root)) {
    kind <- detect_study_kind_from_root(root)
    if (identical(kind, "package")) {
      return(check_package_replication(root, full_replication = full_replication))
    }
    return(check_folder_replication(
      root,
      full_replication = full_replication,
      registry_root = registry_root
    ))
  }
  check_folder_replication(
    location,
    full_replication = full_replication,
    registry_root = registry_root
  )
}

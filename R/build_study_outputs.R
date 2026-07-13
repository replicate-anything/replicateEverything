#' Build display outputs for a study repository
#'
#' Runs pipeline prep steps from `replication.yml` when present, then every
#' registered table and figure, and writes formatted outputs plus
#' `manifest.json`. Works for folder-backed studies (`outputs/`) and
#' package-backed studies (`inst/report/outputs/` or `inst/report/artifacts/`).
#'
#' @param location Local study path, GitHub address, or installed package
#'   name. Defaults to `"."` when the working directory contains
#'   `replication.yml` or `DESCRIPTION`.
#' @param install_deps Logical. Install missing CRAN, pip, and Stata dependencies
#'   when `TRUE`.
#' @param ids Optional character vector of replication ids to build. When
#'   `NULL`, builds every figure and table in `replication.yml`.
#' @param registry_root Optional registry checkout path for monorepo dev
#'   (folder studies only).
#' @param output_dir Optional output directory (package studies only). Defaults to
#'   the package report outputs directory.
#' @param force_prep Logical. Re-run prep steps even when outputs already exist.
#' @return Invisibly, a list with `output_dir`, `manifest`, and per-id status.
#'
#' @examples
#' \dontrun{
#' build_study_outputs(".", install_deps = TRUE)
#' build_study_outputs("rep1371journalpone0278337", install_deps = TRUE)
#' }
#'
#' @export
build_study_outputs <- function(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL,
  output_dir = NULL,
  force_prep = FALSE
) {
  root <- tryCatch(
    resolve_study_root(location),
    error = function(e) NULL
  )
  if (!is.null(root)) {
    kind <- detect_study_kind_from_root(root)
    if (identical(kind, "package")) {
      return(build_package_artifacts(
        package = package_name_from_root(root),
        install_deps = install_deps,
        ids = ids,
        output_dir = output_dir,
        force_prep = force_prep
      ))
    }
    return(build_study_artifacts(
      location = root,
      install_deps = install_deps,
      ids = ids,
      registry_root = registry_root,
      force_prep = force_prep
    ))
  }
  build_package_artifacts(
    package = as.character(location[[1]]),
    install_deps = install_deps,
    ids = ids,
    output_dir = output_dir,
    force_prep = force_prep
  )
}

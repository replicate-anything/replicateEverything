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
#' @param only_missing Logical. When `TRUE`, skip replications whose artifacts
#'   already exist (see [artifact_available()]).
#' @return Invisibly, a list with `output_dir`, `manifest`, and per-id status.
#'
#' @seealso [build_outputs()] for registry-wide or DOI-scoped builds.
#'
#' @examples
#' \dontrun{
#' build_study_outputs(".", install_deps = TRUE)
#' build_study_outputs("rep1371journalpone0278337", install_deps = TRUE)
#' build_study_outputs(".", only_missing = TRUE)
#' }
#'
#' @export
build_study_outputs <- function(
  location = ".",
  install_deps = TRUE,
  ids = NULL,
  registry_root = NULL,
  output_dir = NULL,
  force_prep = FALSE,
  only_missing = FALSE
) {
  loc <- trimws(as.character(location[[1]] %||% location))
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
        force_prep = force_prep,
        only_missing = only_missing
      ))
    }
    return(build_study_artifacts(
      location = root,
      install_deps = install_deps,
      ids = ids,
      registry_root = registry_root,
      force_prep = force_prep,
      only_missing = only_missing
    ))
  }
  if (looks_like_study_alias(loc)) {
    stop(
      "Could not resolve study location: ", loc, ". ",
      "Pass the study repo path (e.g. \"rep-10.5555_cahw\"), call ",
      "configure_local_monorepo(), or set options(replicateEverything.registry_root = ...).",
      call. = FALSE
    )
  }
  build_package_artifacts(
    package = loc,
    install_deps = install_deps,
    ids = ids,
    output_dir = output_dir,
    force_prep = force_prep,
    only_missing = only_missing
  )
}

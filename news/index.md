# Changelog

## replicateEverything 0.2.0

### Major features

- Connect to the public [replication
  registry](https://github.com/replicate-anything/registry) to discover
  and run computational replications by DOI.
- Run a single figure or table with
  [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  /
  [`render_replication()`](https://replicate-anything.github.io/replicateEverything/reference/render_replication.md),
  or reproduce an entire paper with
  [`replicate_paper()`](https://replicate-anything.github.io/replicateEverything/reference/replicate_paper.md).
- Load, validate, and save precomputed artifacts
  ([`load_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact.md),
  [`save_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/save_artifact.md),
  [`validate_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/validate_artifact.md)).
- Optional display pipeline via registered `format_*` functions
  ([`format_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/format_for_display.md),
  [`render_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/render_for_display.md)).
- Package-backed replications: install and call standalone study
  packages from the registry or a local monorepo.
- Contributor tooling:
  [`create_replication_template()`](https://replicate-anything.github.io/replicateEverything/reference/create_replication_template.md)
  scaffolds a new replication folder with `replication.yml`, data, and
  code stubs.
- Registry search and metadata helpers:
  [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md),
  [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md),
  [`get_doi_metadata()`](https://replicate-anything.github.io/replicateEverything/reference/get_doi_metadata.md),
  [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md),
  [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md).
- Local registry development via
  `options(replicateEverything.registry_root = ...)` and
  `options(replicateEverything.index = ...)`.

### Documentation

- Vignette: “Replication Examples Using Code”.
- pkgdown site at
  <https://replicate-anything.github.io/replicateEverything/>.

### Notes

- Network-dependent examples and tests are wrapped in `\dontrun{}` or
  skipped on CRAN.
- Optional dependency installation during replication runs is opt-in via
  `install_deps = TRUE`.

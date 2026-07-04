# Changelog

## replicateEverything 0.4.0

### Public API

- Slim export surface (~16 functions): discovery, run, Shiny,
  contribute, and audit helpers only.
- `run_replication(doi, what = "everything")` replaces
  [`replicate_paper()`](https://replicate-anything.github.io/replicateEverything/reference/replicate_paper.md)
  for full-paper runs.
- Registry `index.csv` includes a `handle` column;
  [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md)
  and run functions accept handles (e.g. `"bounding-causes"`).
- [`replicate_paper()`](https://replicate-anything.github.io/replicateEverything/reference/replicate_paper.md)
  and
  [`create_replication_template()`](https://replicate-anything.github.io/replicateEverything/reference/create_replication_template.md)
  are deprecated.
- [`validate_replication()`](https://replicate-anything.github.io/replicateEverything/reference/validate_replication.md)
  and other internal helpers are no longer exported.
- New vignette: [Meet the
  functions](https://replicate-anything.github.io/replicateEverything/news/articles/meet-the-functions.md).

## replicateEverything 0.3.0

### Folder-backed study workflow

- [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md)
  — run replications and write `artifacts/` + `manifest.json` from a
  study repo.
- [`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md)
  — pre-merge checklist (layout, yaml, code/data paths, artifacts,
  tests).
- [`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_folder_paper.md)
  — build artifacts, validate, write `registry/replication.yml` +
  `registry/index.csv` in study repo.
- [`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_folder_paper.md)
  — copy prepared stub files into a registry checkout.
- [`add_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/add_folder_paper.md)
  — validate and register a folder-backed study stub in the registry.
- [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  — registry-wide audit (Quarto report: `audit_everything.qmd` in the
  registry repo).
- Vignettes: [Registry
  audit](https://replicate-anything.github.io/replicateEverything/news/audit.md)
  and [Stata
  replications](https://replicate-anything.github.io/replicateEverything/news/stata-replications.md).
- Improved artifact error hints for folder-backed studies.

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

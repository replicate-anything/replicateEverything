# replicateEverything 0.4.0

## Public API

* Slim export surface (~16 functions): discovery, run, Shiny, contribute, and audit helpers only.
* `run_replication(doi, what = "everything")` replaces `replicate_paper()` for full-paper runs.
* Registry `index.csv` includes a `handle` column; `search_papers()` and run functions accept handles (e.g. `"bounding-causes"`).
* `replicate_paper()` and `create_replication_template()` are deprecated.
* `validate_replication()` and other internal helpers are no longer exported.
* New vignette: [Meet the functions](articles/meet-the-functions.html).

# replicateEverything 0.3.0

## Folder-backed study workflow

* `build_study_artifacts()` — run replications and write `artifacts/` + `manifest.json` from a study repo.
* `check_folder_replication()` — pre-merge checklist (layout, yaml, code/data paths, artifacts, tests).
* `prepare_folder_paper()` — build artifacts, validate, write `registry/replication.yml` + `registry/index.csv` in study repo.
* `sync_folder_paper()` — copy prepared stub files into a registry checkout.
* `add_folder_paper()` — validate and register a folder-backed study stub in the registry.
* `audit_everything()` — registry-wide audit (Quarto report: `audit_everything.qmd` in the registry repo).
* Vignettes: [Registry audit](audit.html) and [Stata replications](stata-replications.html).
* Improved artifact error hints for folder-backed studies.

# replicateEverything 0.2.0

## Major features

* Connect to the public [replication registry](https://github.com/replicate-anything/registry) to discover and run computational replications by DOI.
* Run a single figure or table with `run_replication()` / `render_replication()`, or reproduce an entire paper with `replicate_paper()`.
* Load, validate, and save precomputed artifacts (`load_artifact()`, `save_artifact()`, `validate_artifact()`).
* Optional display pipeline via registered `format_*` functions (`format_for_display()`, `render_for_display()`).
* Package-backed replications: install and call standalone study packages from the registry or a local monorepo.
* Contributor tooling: `create_replication_template()` scaffolds a new replication folder with `replication.yml`, data, and code stubs.
* Registry search and metadata helpers: `search_papers()`, `load_index()`, `get_doi_metadata()`, `list_replications()`, `get_code()`.
* Local registry development via `options(replicateEverything.registry_root = ...)` and `options(replicateEverything.index = ...)`.

## Documentation

* Vignette: "Replication Examples Using Code".
* pkgdown site at https://replicate-anything.github.io/replicateEverything/.

## Notes

* Network-dependent examples and tests are wrapped in `\dontrun{}` or skipped on CRAN.
* Optional dependency installation during replication runs is opt-in via `install_deps = TRUE`.

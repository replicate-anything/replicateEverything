# Changelog

## replicateEverything 0.5.0

### Bug fixes

- Study Stata dependency scripts (`install_stata_deps.do` etc.) now run
  at most once per study per session instead of before every prep step
  and table, so repeated live runs no longer re-trigger a slow SSC
  reinstall/recompile. A missing-dependency retry still forces a re-run.
  Set `options(replicateEverything.install_stata_deps = FALSE)` to skip
  study dependency installation entirely when you manage Stata packages
  yourself.
- Cached GitHub study checkouts now refresh when the remote commit
  changes.
  [`materialize_folder_study_from_github()`](https://replicate-anything.github.io/replicateEverything/reference/materialize_folder_study_from_github.md)
  records the downloaded commit SHA and compares it against the current
  remote SHA (via the GitHub API); a stale cache (e.g. one built before
  new data files were committed) is re-downloaded automatically. When
  the remote SHA cannot be determined (offline or rate-limited) the
  existing cache is kept. This fixes live Stata/Python runs failing with
  “file not found” for data that exists in the repo but was missing from
  an out-of-date server cache. The remote check is on-demand (only when
  a study is actually run/fetched from GitHub) and is skipped for a
  short, per-session window after a study is confirmed fresh, so
  repeated resolutions within one run make at most one API call per
  study; tune with
  `options(replicateEverything.study_cache_ttl = <seconds>)` (default
  300; 0 to always check).
- Python replications now run from the resolved study folder (the local
  sibling or the materialized GitHub clone) instead of falling back to
  the R working directory. On a Shiny server this fixes
  `FileNotFoundError` where `REPLICATE_STUDY_ROOT` pointed at the app
  directory (e.g. `ShinyApps/replicate/data/raw/...`) rather than the
  study repo clone. The Python process now also runs with its working
  directory set to the study root, matching Stata.
- Python dependency handling now probes whether each declared package is
  already importable (`python -c "import ..."`) before shelling out to
  `pip`, so live runs skip redundant installs and no longer fail on
  locked-down servers where the packages are pre-installed but
  `pip install` is forbidden. Also fixed the pip exit-status check,
  which previously misread
  [`system2()`](https://rdrr.io/r/base/system2.html) captured output as
  the status code.
- [`ai_skills()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skills.md)
  no longer lists `README.md` as a skill; `inst/ai/skills/` now bundles
  both `folder_replication` and `APSR_to_replicateEverything`.

### Breaking changes

- Removed deprecated `replicate_paper()` and
  `create_replication_template()`. Use
  `run_replication(doi, "everything")` and the folder/package
  replication checklists instead.
- Pre-built vignette HTML is shipped again in `inst/doc/` so installs
  that skip vignette builds still include all articles.

### Documentation

- [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
  appears under **Run replications** in the pkgdown reference index.
- **Meet the functions** vignette reorganized into consumer and
  contributor sections.
- Bundled AI skills under `inst/ai/skills/` with
  [`ai_skills()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skills.md),
  [`ai_skill_path()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skill_path.md),
  and
  [`ai_skill()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skill.md).

## replicateEverything 0.4.0

### Public API

- Slim export surface (~14 functions): discovery, run, Shiny,
  contribute, and audit helpers only.
- `run_replication(doi, what = "everything")` replaces
  `replicate_paper()` for full-paper runs.
- Registry `index.csv` includes a `handle` column;
  [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md)
  and run functions accept handles (e.g. `"bounding-causes"`).
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
  or reproduce an entire paper with `replicate_paper()`.
- Load, validate, and save precomputed artifacts
  ([`load_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact.md),
  [`save_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/save_artifact.md),
  [`validate_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/validate_artifact.md)).
- Optional display pipeline via registered `format_*` functions
  ([`format_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/format_for_display.md),
  [`render_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/render_for_display.md)).
- Package-backed replications: install and call standalone study
  packages from the registry or a local monorepo.
- Contributor tooling: `create_replication_template()` scaffolds a new
  replication folder with `replication.yml`, data, and code stubs.
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

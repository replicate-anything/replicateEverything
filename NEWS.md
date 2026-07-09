# replicateEverything 0.5.0

## Policy

* Exported maintainer API: [check_study_compatibility()], [install_study_dependencies()] (folder + package registry studies), [install_registry_dependencies()], [replication_kind()], [study_artifact_dir()], and [maintainer_dependency_hint()].

## Bug fixes

* Stata dependency checks are **study-declared** via `stata_deps_probe:` (check-only `.do` in the study repo) or `stata_packages:` (generic `which`-only probe). The package no longer hardcodes ftools/reghdfe/estout. Live Run probes only; `install_stata_deps.do` runs only when `options(replicateEverything.install_stata_deps = TRUE)` (e.g. `build_study_artifacts(install_deps = TRUE)`).
* Stata dependency probe and study `install_stata_deps.do` load tests use `help reghdfe` instead of bare `reghdfe` where applicable (study probe script). Invoking `reghdfe` with no data returns r(301) even when installed. When satisfied (as on a typical dev machine), the install script is skipped and Shiny shows "Stata dependencies OK — skipped install". Install runs only when the probe fails. Progress lines are reported via `replicate_progress()` / `options(replicateEverything.progress)` for Shiny's "Working:" banner.
* Stata batch runs honour `timeout` when the suggested **processx** package is installed; overdue runs are killed so Shiny can recover instead of freezing indefinitely. Tune with `options(replicateEverything.stata_timeout)`, `stata_deps_probe_timeout` (default 120s), and `stata_deps_install_timeout` (default 600s). Set `options(replicateEverything.install_stata_deps = FALSE)` to skip study Stata installs entirely.
* Shiny artifact loading no longer passes `install_deps = TRUE` (only live Run installs dependencies).
* Study cache downloads unzip on the same filesystem as the cache directory (not system `/tmp`), so moving the extracted repo into the cache is atomic on Linux servers where `/tmp` and the Samba/NFS cache are on different mounts. The cross-device `file.rename` fallback also uses a single recursive copy and suppresses the EXDEV warning.
* Study Stata dependency scripts (`install_stata_deps.do` etc.) now run at most once per study per session instead of before every prep step and table, so repeated live runs no longer re-trigger a slow SSC reinstall/recompile. A missing-dependency retry still forces a re-run. Set `options(replicateEverything.install_stata_deps = FALSE)` to skip study dependency installation entirely when you manage Stata packages yourself.
* Cached GitHub study checkouts now refresh when the remote commit changes. `materialize_folder_study_from_github()` records the downloaded commit SHA and compares it against the current remote SHA (via the GitHub API); a stale cache (e.g. one built before new data files were committed) is re-downloaded automatically. When the remote SHA cannot be determined (offline or rate-limited) the existing cache is kept. This fixes live Stata/Python runs failing with "file not found" for data that exists in the repo but was missing from an out-of-date server cache. The remote check is on-demand (only when a study is actually run/fetched from GitHub) and is skipped for a short, per-session window after a study is confirmed fresh, so repeated resolutions within one run make at most one API call per study; tune with `options(replicateEverything.study_cache_ttl = <seconds>)` (default 300; 0 to always check).
* Python replications now run from the resolved study folder (the local sibling or the materialized GitHub clone) instead of falling back to the R working directory. On a Shiny server this fixes `FileNotFoundError` where `REPLICATE_STUDY_ROOT` pointed at the app directory (e.g. `ShinyApps/replicate/data/raw/...`) rather than the study repo clone. The Python process now also runs with its working directory set to the study root, matching Stata.
* Python dependency probing uses `importlib.util.find_spec` per package, prefers the Windows `py -0p` launcher installs over Store stubs, and skips `WindowsApps` aliases on PATH. Compatibility UI shows the full Python path probed.
* `ai_skills()` no longer lists `README.md` as a skill; `inst/ai/skills/` now bundles both `folder_replication` and `APSR_to_replicateEverything`.

## Breaking changes

* Removed deprecated `replicate_paper()` and `create_replication_template()`. Use `run_replication(doi, "everything")` and the folder/package replication checklists instead.
* Pre-built vignette HTML is shipped again in `inst/doc/` so installs that skip vignette builds still include all articles.

## Documentation

* `get_code()` appears under **Run replications** in the pkgdown reference index.
* **Meet the functions** vignette reorganized into consumer and contributor sections.
* Bundled AI skills under `inst/ai/skills/` with `ai_skills()`, `ai_skill_path()`, and `ai_skill()`.

# replicateEverything 0.4.0

## Public API

* Slim export surface (~14 functions): discovery, run, Shiny, contribute, and audit helpers only.
* `run_replication(doi, what = "everything")` replaces `replicate_paper()` for full-paper runs.
* Registry `index.csv` includes a `handle` column; `search_papers()` and run functions accept handles (e.g. `"bounding-causes"`).
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

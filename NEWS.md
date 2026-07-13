# replicateEverything 0.6.0

## Public API cleanup

* **Unified contribute API:** [build_study_outputs()] replaces [build_study_artifacts()] and [build_package_artifacts()]; [check_replication()] replaces [check_folder_replication()] and [check_package_replication()]. The kind-specific functions remain internal.
* Removed deprecated exports: `list_replication_groups()`, `list_prep_steps()`, `prepare_folder_paper()`, and `sync_folder_paper()`.
* Internal (no longer in Reference): `print(<replication_list>)`, [study_dag_display()], [study_dag_facets()], [study_output_dir()], [migrate_legacy_steps_yaml()], [run_prep_step()], and [replication_kind()].
* [refresh_registry()] moved to the **Registry audit** reference section.

## Step DAG and conditional replication

* Unified **`steps:`** block in `replication.yml` replaces separate `prep:` / `replications:` (legacy blocks still compile automatically).
* [run_replication()] gains **`given`** (`"parents"`, `"nothing"`, or a character vector of assumed-complete steps) and **`force`**. Default `given = "parents"` requires immediate parent outputs to exist and errors if missing.
* Shiny shows a **faceted** pipeline (Tables / figures / standalone paths) with hover labels; step **labels** name outputs.
* Study products live under **`outputs/`** (step-named paths); **`artifacts/`** is no longer used for folder-backed studies.
* **`language`** is optional in [run_replication()] when a replication has only one engine.
* Shiny: collapsible study details (expand after DOI); simplified pipeline key; **Pipeline** tab per object.
* Shiny: fixed study deep links (`?doi=...`) — wait for browser URL before parsing; skip welcome modal when opening a shared link.
* Removed legacy path fallbacks (`artifacts/`, `data/processed/` as implicit output locations). Study repos must declare and write **`outputs/`** paths explicitly.
* Format steps are **`type: format`** children of tables/figures; run via `format = TRUE` unless `format = FALSE`.
* [configure_local_monorepo()] wires registry + sibling study folders for local dev.
* [study_output_dir()] is the preferred name for the display output directory; [study_artifact_dir()] is now internal.
* **Step inheritance** — extension studies declare `paper.extends` and `inherit:` steps; inherited pipeline steps run in the base repo, extension analyses read base `outputs/`. New vignette: `vignette("reanalysis-studies")`. Worked example: Fearon & Laitin reanalysis (`rep-10.1017-S0003055403000534--alt-1`).
* Studies without an article DOI may use **`paper.study_handle`** (registry handle) instead of `paper.doi`.
* **`paper.article_url`** — optional publisher landing page when `https://doi.org/...` fails; [paper_article_url()] and Shiny bibliography links use it. Registry `index.csv` carries `article_url` when set in the stub.
* [list_replications()] gains **`grouped`**, **`include`** (`"display"`, `"pipeline"`, `"all"`), consolidating [list_replication_groups()] and [list_prep_steps()] (both deprecated).
* New overview vignette: **`vignette("why-replicateEverything")`** (first article on the site).
* [list_replications()] gains a compact **print method** (`replication_list` class). `given` defaults to `"nothing"` when `what = "everything"`.
* [audit_everything()] runs published-value checks from `tests/substantive/<step_id>.R` when present (`substantive = TRUE` by default). [check_replication()] reports substantive coverage and runs defined checks when `full_replication = TRUE`. New helper: [check_glm_table_benchmark()] for logit tables. Filter audits with **`collections =`** (e.g. `"APSR"`) or `dois =`.
* Package website: serve from **`docs/` on `main`**; run `Rscript scripts/build_pkgdown.R` locally and commit the full `docs/` tree (not CI). pkgdown CI workflow is manual-only (`workflow_dispatch`).
* Live replication and Shiny **Run** now execute missing **upstream DAG steps** (`parents:`) before tables and figures; Shiny loads merged study metadata for pipeline graphs and handle-only registry entries.
* **Output convention:** transform steps write flat `outputs/<step_id>.<ext>` (e.g. `outputs/analysis_data.rds`); data steps appear in the Shiny sidebar with Display/Run and `head()` kable preview; pipeline labels add **(R)** / **(Stata)** when the same table label appears twice.
* **Registry handoff:** [prepare_study_for_registry()] (contributor) validates a folder- or package-backed study and writes short yaml to `registry/` or `inst/registry/`. [sync_study_to_registry()] and [refresh_registry()] (maintainer) install stubs, rebuild `index.csv`, and optionally rerun [audit_everything()]. New skill: `include_study_in_registry.md`.

# replicateEverything 0.5.1

## Registry index and Shiny

* Registry `index.csv` supports **`collections`**, **`maintainer_name`**, **`maintainer_email`**, and precompiled **`languages`** so the Studies tab does not fetch each study repo on load.
* Shiny study selector uses **bibliographic labels** (`Acemoglu et al (2001)`) sorted by first author and year.
* Studies tab: **collection tags column** (APSR, PED, WB, IPI; max three per row) with legend; **maintainer** link on study details (`[maintainer]` hover).
* Registry study stubs (`studies/*.yml`) now carry **`maintainer`**, **`collections`**, and **`languages`**; [build_registry_index()] compiles `index.csv` from stubs alone.
* Button renamed to **Check system compatibility**.

## Bug fixes

* Shiny footer shows package and app **commit SHA** (`pkg` / `app`) instead of the library install path, so it is easy to see when a deployed `app.R` is stale relative to the installed package. `save_local_shiny()` writes `BUNDLE_SHA` into the deploy directory; a warning banner appears when `app` and `pkg` SHAs differ.
* Fixed Shiny footer crash (`do.call(tag, ...)` — second argument must be a list) from malformed tag construction in `app_build_footer_ui()`.
* `stata_packages:` — auto install and probe from SSC (including `reghdfe` / GitHub conflict handling). Custom `stata_dependencies:` / `stata_deps_probe:` `.do` files are optional for rare cases only.
* Shiny dependency-error UI no longer calls internal `replication_error_message()` as a global function.

## New functions

* [package_build_info()] — version plus GitHub `RemoteSha` or bundled `BUNDLE_SHA`.

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
* Renamed bundled skill `APSR_to_replicateEverything` → `dataverse_to_replicateEverything` (Harvard Dataverse deposits generally; `collections: APSR` only when metadata cites *American Political Science Review*). Step 1b now requires downloading the author README from the deposit before scaffolding.

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

* `build_study_artifacts()` — run replications and write `outputs/` + `manifest.json` from a study repo.
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
